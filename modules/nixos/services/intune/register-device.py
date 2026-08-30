import argparse
import asyncio
import base64
import json
import os
import re
import socket
import subprocess
import sys
import time
import uuid

from dbus_next import BusType, Message, MessageType
from dbus_next.aio import MessageBus

DBUS_DESTINATION = "com.microsoft.identity.devicebroker1"
DBUS_INTERFACE = "com.microsoft.identity.DeviceBroker1"
DBUS_PATH = "/com/microsoft/identity/devicebroker1"
DRS_AUDIENCE = "urn:ms-drs:enterpriseregistration.windows.net"
DSREG = os.environ["INTUNE_DSREG"]
SYSTEMCTL = os.environ["INTUNE_SYSTEMCTL"]
PROTOCOL_VERSION = "0.1"


class RegistrationError(RuntimeError):
    pass


def run_dsreg(*arguments):
    return subprocess.run(
        [DSREG, *arguments],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=60,
    )


def status_values(output, field):
    pattern = rf"^{re.escape(field)}\s*:\s*(.*?)\s*$"
    return re.findall(pattern, output, re.MULTILINE)


def normalize_tenant_id(value):
    try:
        return str(uuid.UUID(value))
    except ValueError as error:
        raise RegistrationError(f"Invalid tenant ID: {value!r}") from error


def inspect_registration_state(requested_tenant):
    result = run_dsreg("--status")
    if result.returncode != 0:
        raise RegistrationError(
            "Unable to query the Microsoft Identity Broker with dsreg."
        )

    output = result.stdout
    registration = status_values(output, "Device Registration Status")
    device_ids = status_values(output, "Device ID")
    tenant_ids = {
        normalize_tenant_id(value)
        for value in status_values(output, "Tenant ID")
        if value
    }

    if registration and registration[0] == "Registered":
        device_id = device_ids[0] if device_ids else "unknown"
        print(f"Device is already registered: {device_id}")
        return None

    if requested_tenant:
        tenant_id = normalize_tenant_id(requested_tenant)
    elif len(tenant_ids) == 1:
        tenant_id = tenant_ids.pop()
    else:
        raise RegistrationError(
            "No unambiguous tenant ID is available. Run Microsoft Intune "
            "until sign-in reaches AADSTS50129, or pass --tenant-id."
        )

    prt_state = status_values(output, "PRT Present")
    if not prt_state or prt_state[0] != "YES":
        raise RegistrationError(
            "No Primary Refresh Token is available. Run Microsoft Intune "
            "until sign-in reaches AADSTS50129, then run this command again."
        )

    return tenant_id


def decode_jwt_claims(token):
    parts = token.split(".")
    if len(parts) != 3:
        raise RegistrationError("dsreg did not return a JWT access token.")

    try:
        padding = "=" * (-len(parts[1]) % 4)
        payload = base64.urlsafe_b64decode(parts[1] + padding)
        return json.loads(payload)
    except (ValueError, json.JSONDecodeError) as error:
        raise RegistrationError(
            "Unable to validate the DRS access token."
        ) from error


def acquire_drs_token(tenant_id):
    result = run_dsreg("--tenant-id", tenant_id, "--getdrstoken")
    if result.returncode != 0:
        detail = result.stderr.strip()
        if detail:
            raise RegistrationError(f"DRS token acquisition failed: {detail}")
        raise RegistrationError("DRS token acquisition failed.")

    token = result.stdout.strip()
    claims = decode_jwt_claims(token)
    audience = claims.get("aud")
    if audience != DRS_AUDIENCE:
        raise RegistrationError(f"Unexpected DRS token audience: {audience!r}")

    expires_at = claims.get("exp")
    if not isinstance(expires_at, int) or expires_at <= int(time.time()):
        raise RegistrationError("The DRS access token is already expired.")

    return token


def summarize_error(error):
    return {
        "context": error.get("context"),
        "errorCode": error.get("errorCode"),
        "status": error.get("status"),
        "subStatus": error.get("subStatus"),
        "tag": error.get("tag"),
        "diagnostics": error.get("diagnostics"),
    }


async def register_device(tenant_id, token):
    correlation_id = str(uuid.uuid4())
    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
    try:
        request = json.dumps(
            {"tenantId": tenant_id, "at": token},
            separators=(",", ":"),
        )
        reply = await asyncio.wait_for(
            bus.call(
                Message(
                    destination=DBUS_DESTINATION,
                    path=DBUS_PATH,
                    interface=DBUS_INTERFACE,
                    member="registerDevice",
                    signature="sss",
                    body=[PROTOCOL_VERSION, correlation_id, request],
                )
            ),
            timeout=60,
        )
    finally:
        bus.disconnect()

    if reply.message_type == MessageType.ERROR:
        raise RegistrationError(
            f"D-Bus registerDevice failed: {reply.error_name}"
        )

    response = json.loads(reply.body[0])
    error = response.get("error")
    if error:
        print(
            json.dumps(
                {
                    "registered": False,
                    "correlationId": correlation_id,
                    "error": summarize_error(error),
                },
                indent=2,
            )
        )
        return False

    print(
        json.dumps(
            {"registered": True, "correlationId": correlation_id},
            indent=2,
        )
    )
    return True


def verify_registration():
    result = run_dsreg("--status")
    if result.returncode != 0:
        raise RegistrationError(
            "Registration succeeded but dsreg verification failed."
        )

    registration = status_values(
        result.stdout,
        "Device Registration Status",
    )
    if not registration or registration[0] != "Registered":
        raise RegistrationError(
            "The broker returned success, but dsreg still reports "
            "Not Registered."
        )

    device_ids = status_values(result.stdout, "Device ID")
    return device_ids[0] if device_ids else "unknown"


def stop_user_sessions():
    result = subprocess.run(
        [
            SYSTEMCTL,
            "--user",
            "list-units",
            "app-intune*",
            "dbus-*com.microsoft.identity.broker1*",
            "--all",
            "--no-legend",
            "--plain",
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=15,
    )
    units = [
        line.split(maxsplit=1)[0]
        for line in result.stdout.splitlines()
        if line.strip()
    ]
    if not units:
        return

    stopped = subprocess.run(
        [SYSTEMCTL, "--user", "stop", *units],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        timeout=15,
    )
    if stopped.returncode != 0:
        print(
            "warning: unable to stop the active Intune/broker session; "
            "close Microsoft Intune manually before reopening it.",
            file=sys.stderr,
        )


def parse_arguments():
    parser = argparse.ArgumentParser(
        prog="intune-register-device",
        description=(
            "Manually invoke Microsoft Identity Broker device registration "
            "after Company Portal fails with AADSTS50129."
        )
    )
    parser.add_argument(
        "--tenant-id",
        help="Microsoft Entra tenant UUID; inferred from dsreg when omitted.",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Skip the interactive confirmation.",
    )
    return parser.parse_args()


def main():
    if os.geteuid() == 0:
        raise RegistrationError(
            "Run this command as the signed-in desktop user, not as root."
        )

    arguments = parse_arguments()
    tenant_id = inspect_registration_state(arguments.tenant_id)
    if tenant_id is None:
        return 0

    print(f"Tenant: {tenant_id}")
    print(f"Device: {socket.gethostname()}")
    print(
        "This creates a Microsoft Entra device identity and consumes one "
        "device quota slot."
    )
    if not arguments.yes:
        answer = input("Continue with device registration? [y/N] ")
        if answer.strip().lower() not in {"y", "yes"}:
            print("Registration canceled.")
            return 1

    token = acquire_drs_token(tenant_id)
    try:
        if not asyncio.run(register_device(tenant_id, token)):
            return 1
    finally:
        token = None

    device_id = verify_registration()
    stop_user_sessions()
    print(f"Registered device ID: {device_id}")
    print("Reopen Microsoft Intune to continue enrollment.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RegistrationError, subprocess.TimeoutExpired) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1) from None
