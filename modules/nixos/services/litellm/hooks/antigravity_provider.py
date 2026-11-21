"""Gemini over Antigravity Cloud Code, without patching LiteLLM.

Protocol reference: can1357/oh-my-pi@852eb2d, google-gemini-cli.ts and
registry/oauth/google-antigravity.ts (MIT). Gemini conversion stays in LiteLLM.
Run this file with `login` inside the LiteLLM Python environment to connect.
"""

from __future__ import annotations

import asyncio
import base64
import copy
import fcntl
import hashlib
import json
import os
import secrets
import stat
import sys
import tempfile
import time
import urllib.parse
import uuid
from collections.abc import AsyncIterator, Iterator
from pathlib import Path
from typing import Any

import httpx
from litellm import CustomLLM, ModelResponse
from litellm.litellm_core_utils.prompt_templates.image_handling import (
    async_inline_remote_media,
)
from litellm.llms.custom_llm import CustomLLMError
from litellm.llms.gemini.chat.transformation import GoogleAIStudioGeminiConfig
from litellm.llms.vertex_ai.common_utils import build_vertex_schema
from litellm.llms.vertex_ai.gemini.transformation import transform_request_body
from litellm.llms.vertex_ai.gemini.vertex_and_google_ai_studio_gemini import (
    ModelResponseIterator,
    VertexGeminiConfig,
)

ENDPOINT = "https://daily-cloudcode-pa.googleapis.com"
TOKEN_URL = "https://oauth2.googleapis.com/token"
# The native client's OAuth client ID/secret come from litellm-env (SOPS secrets
# antigravity-oauth-client-{id,secret}) so they are not committed to the public repository.
# agy 1.5.6's interactive consumer login uses a hosted callback and PKCE.
REDIRECT_URI = "https://antigravity.google/oauth-callback"
SCOPES = " ".join(
    (
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/cclog",
        "https://www.googleapis.com/auth/experimentsandconfigs",
        "https://www.googleapis.com/auth/aicode",
        "openid",
    )
)
SKIP_SIGNATURE = "skip_thought_signature_validator"
ENCODED_SKIP_SIGNATURE = base64.b64encode(SKIP_SIGNATURE.encode()).decode()
# Antigravity's Gemini location gate rejects lumine's Azure IPv6 egress while
# accepting its IPv4 egress from the same region (measured 2026-11-18). httpx's
# async transport prefers IPv6, so bind every Google request to IPv4.
IPV4 = "0.0.0.0"


def _http() -> httpx.Client:
    return httpx.Client(transport=httpx.HTTPTransport(local_address=IPV4), timeout=30)


def _credential_path() -> Path:
    return (
        Path(
            os.environ.get(
                "ANTIGRAVITY_TOKEN_DIR", str(Path.home() / ".config/antigravity")
            )
        )
        / "credentials.json"
    )


def _headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "User-Agent": os.environ["ANTIGRAVITY_USER_AGENT"],
        "Accept-Encoding": "gzip",
    }


def _check(response: httpx.Response) -> dict:
    if response.is_error:
        raise CustomLLMError(response.status_code, f"Antigravity: {response.text}")
    result = response.json()
    if "error" in result:
        error = result["error"]
        raise CustomLLMError(
            error.get("code", 502), f"Antigravity: {json.dumps(error)}"
        )
    return result


def _client_credentials() -> dict[str, str]:
    try:
        return {
            "client_id": os.environ["ANTIGRAVITY_OAUTH_CLIENT_ID"],
            "client_secret": os.environ["ANTIGRAVITY_OAUTH_CLIENT_SECRET"],
        }
    except KeyError as missing:
        raise CustomLLMError(
            500, f"Antigravity OAuth client is not configured: {missing}"
        ) from None


def _token(**fields: str) -> dict:
    with _http() as client:
        return _check(client.post(TOKEN_URL, data={**_client_credentials(), **fields}))


def _refresh_token(refresh_token: str) -> dict:
    result = _token(grant_type="refresh_token", refresh_token=refresh_token)
    result.setdefault("refresh_token", refresh_token)
    return result


def _control(client: httpx.Client, method: str, token: str, body: dict) -> dict:
    return _check(
        client.post(f"{ENDPOINT}/v1internal:{method}", json=body, headers=_headers(token))
    )


def _catalog(client: httpx.Client, token: str, project: str) -> dict:
    result = _control(client, "fetchAvailableModels", token, {"project": project})
    return {
        "models": result["models"],
        # agy selects a family's SKU by effort suffix, e.g. gemini-4-neon-xhigh.
        "groups": {
            family: [level["thinkingSuffix"] for level in group["supportedThinkingLevels"]]
            for family, group in result.get("groupedModels", {}).items()
        },
        "default": result.get("defaultAgentModelId", ""),
        "fetched_at": time.time(),
    }


def _route(catalog: dict, family: str, effort: str | None) -> tuple[str, dict | None]:
    efforts = catalog["groups"].get(family)
    if efforts is None:
        wire = family
    else:
        if effort is None:
            # agy defaults to the account default's effort within its family, else medium.
            default = catalog["default"]
            effort = default.removeprefix(f"{family}-") if default.startswith(f"{family}-") else "medium"
        if effort not in efforts:
            raise CustomLLMError(
                400, f"{family} has no {effort!r} effort (available: {', '.join(efforts)})"
            )
        wire = f"{family}-{effort}"
    profile = catalog["models"].get(wire)
    if not profile or profile.get("disabled") or profile.get("isInternal"):
        return wire, None
    return wire, profile


def _project(client: httpx.Client, token: str) -> str:
    metadata = {"ideType": "ANTIGRAVITY"}
    result = _control(client, "loadCodeAssist", token, {"metadata": metadata})
    project = result.get("cloudaicompanionProject")
    if project and not result.get("paidTier"):
        result = _control(
            client,
            "loadCodeAssist",
            token,
            {"metadata": metadata, "cloudaicompanionProject": project},
        )
    if not result.get("currentTier"):
        # A paid/active account may list free-tier as ineligible. That does not
        # invalidate its current entitlement or its existing Cloud Code project.
        if not any(t.get("id") == "free-tier" for t in result.get("allowedTiers", [])):
            for tier in result.get("ineligibleTiers", []):
                if tier.get("tierId") == "free-tier" and tier.get("reasonMessage"):
                    raise CustomLLMError(
                        403, f"{tier['reasonMessage']} {tier.get('validationUrl', '')}"
                    )
        operation = _control(
            client,
            "onboardUser", token, {"metadata": metadata, "tierId": "free-tier"}
        )
        deadline = time.monotonic() + 30
        while not operation.get("done"):
            if time.monotonic() >= deadline:
                raise CustomLLMError(504, "Antigravity onboarding timed out")
            time.sleep(1)
            operation = _check(
                client.get(
                    f"{ENDPOINT}/v1internal/{operation['name']}",
                    headers=_headers(token),
                )
            )
        if operation.get("error"):
            raise CustomLLMError(403, json.dumps(operation["error"]))
    project = _control(client, "loadCodeAssist", token, {"metadata": metadata}).get(
        "cloudaicompanionProject"
    )
    if not isinstance(project, str) or not project:
        raise CustomLLMError(403, "Antigravity did not return a Cloud Code project")
    return project


def _save(path: Path, credentials: dict) -> None:
    fd, name = tempfile.mkstemp(prefix=".credentials-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(credentials, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def _credentials(refresh_catalog: bool = False) -> dict:
    path = _credential_path()
    if not path.exists():
        raise CustomLLMError(
            401, "Antigravity is not connected; run antigravity_provider.py login"
        )
    if stat.S_IMODE(path.stat().st_mode) & 0o077:
        raise CustomLLMError(401, "Antigravity credentials.json must have mode 0600")
    # Google may rotate refresh tokens. Serialize read/refresh/replace across workers.
    lock_fd = os.open(path.parent / ".lock", os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(lock_fd, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        credentials = json.loads(path.read_text())
        if "session_id" not in credentials:
            # agy sends one sessionId for every conversation of an installation.
            credentials["session_id"] = "-" + str(secrets.randbits(63))
            _save(path, credentials)
        stale = "catalog" not in credentials or (
            refresh_catalog and credentials["catalog"]["fetched_at"] <= time.time() - 60
        )
        if credentials["expires_at"] <= time.time() + 60:
            result = _refresh_token(credentials["refresh_token"])
            credentials.update(
                access_token=result["access_token"],
                refresh_token=result["refresh_token"],
                expires_at=time.time() + result["expires_in"],
            )
            # A catalog outage must not discard a newly rotated refresh token.
            _save(path, credentials)
            stale = True
        if stale:
            with _http() as client:
                credentials["catalog"] = _catalog(
                    client, credentials["access_token"], credentials["project"]
                )
            credentials.pop("models", None)
            _save(path, credentials)
        return credentials


def _start_login() -> None:
    print(
        "Warning: Google has suspended Antigravity accounts for third-party OAuth use.",
        file=sys.stderr,
    )
    verifier = secrets.token_urlsafe(48)
    challenge = (
        base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest())
        .decode()
        .rstrip("=")
    )
    state = secrets.token_urlsafe(32)
    path = _credential_path().parent / ".oauth.json"
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    _save(path, {"state": state, "verifier": verifier})
    params = {
        "client_id": _client_credentials()["client_id"],
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "scope": SCOPES,
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
    }
    print(
        "Open this URL, then paste the authorization code or full callback URL:",
        flush=True,
    )
    print(
        "https://accounts.google.com/o/oauth2/v2/auth?"
        + urllib.parse.urlencode(params, quote_via=urllib.parse.quote),
        flush=True,
    )


def _finish_login() -> None:
    pending_path = _credential_path().parent / ".oauth.json"
    if stat.S_IMODE(pending_path.stat().st_mode) & 0o077:
        raise ValueError("Antigravity .oauth.json must have mode 0600")
    pending = json.loads(pending_path.read_text())
    result = pending.get("tokens")
    if result is None:
        code = input("Authorization code or callback URL: ").strip()
        callback = urllib.parse.urlsplit(code)
        if callback.scheme or callback.netloc:
            if callback._replace(query="", fragment="").geturl() != REDIRECT_URI:
                raise ValueError("Unexpected Antigravity OAuth callback URL")
            query = urllib.parse.parse_qs(callback.query)
            if not secrets.compare_digest(query.get("state", [""])[0], pending["state"]):
                raise ValueError("OAuth state mismatch")
            if "error" in query:
                raise ValueError(query["error"][0])
            code = query.get("code", [""])[0]
        if not code:
            raise ValueError("Missing OAuth authorization code")
        result = _token(
            grant_type="authorization_code",
            code=code,
            code_verifier=pending["verifier"],
            redirect_uri=REDIRECT_URI,
        )
        pending.pop("verifier")
        pending.update(tokens=result, expires_at=time.time() + result["expires_in"])
        # Authorization codes are single-use: retain the token before any
        # account/project/catalog call that can reject access or time out.
        _save(pending_path, pending)
    elif pending["expires_at"] <= time.time() + 60:
        result = _refresh_token(result["refresh_token"])
        pending.update(tokens=result, expires_at=time.time() + result["expires_in"])
        _save(pending_path, pending)
    try:
        with _http() as client:
            project = _project(client, result["access_token"])
            catalog = _catalog(client, result["access_token"], project)
    except CustomLLMError as error:
        raise CustomLLMError(
            error.status_code,
            f"{error.message}\nOAuth credentials retained in the private pending login file. "
            "After resolving account access, run login --finish again.",
        ) from error
    credentials = {
        "refresh_token": result["refresh_token"],
        "access_token": result["access_token"],
        "expires_at": pending["expires_at"],
        "project": project,
        "catalog": catalog,
    }
    path = _credential_path()
    lock_fd = os.open(path.parent / ".lock", os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(lock_fd, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        _save(path, credentials)
    pending_path.unlink()
    print(f"Connected; credentials saved to {path}. Gemini models and efforts:")
    for family, efforts in sorted(catalog["groups"].items()):
        if family.startswith("gemini-"):
            print(f"  {family}: {', '.join(efforts)}")


def _camel_request(body: dict) -> dict:
    """Normalize proto fields only: never rename tool arguments or schema properties."""
    rename = {
        "system_instruction": "systemInstruction",
        "function_call": "functionCall",
        "function_response": "functionResponse",
        "function_declarations": "functionDeclarations",
        "inline_data": "inlineData",
        "file_data": "fileData",
        "mime_type": "mimeType",
        "file_uri": "fileUri",
        "max_output_tokens": "maxOutputTokens",
        "stop_sequences": "stopSequences",
        "candidate_count": "candidateCount",
        "response_mime_type": "responseMimeType",
        "response_schema": "responseSchema",
        "response_json_schema": "responseJsonSchema",
        "top_p": "topP",
        "top_k": "topK",
        "allowed_function_names": "allowedFunctionNames",
    }
    opaque = {
        "args",
        "response",
        "parameters",
        "parametersJsonSchema",
        "responseSchema",
        "responseJsonSchema",
    }

    def convert(value: Any) -> Any:
        if isinstance(value, list):
            return [convert(v) for v in value]
        if not isinstance(value, dict):
            return value
        result = {}
        for key, item in value.items():
            key = rename.get(key, key)
            result[key] = item if key in opaque else convert(item)
        return result

    return convert(body)


class AntigravityProvider(CustomLLM):
    async def _request(
        self, model: str, messages: list, optional_params: dict
    ) -> tuple[dict, dict]:
        effort = optional_params.get("reasoning_effort")
        if isinstance(effort, dict):
            effort = effort.get("effort")
        credentials = await asyncio.to_thread(_credentials)
        wire, profile = _route(credentials["catalog"], model, effort)
        if profile is None:
            # Entitlements change between token refreshes; recheck the live roster.
            credentials = await asyncio.to_thread(_credentials, True)
            wire, profile = _route(credentials["catalog"], model, effort)
            if profile is None:
                raise CustomLLMError(404, f"Antigravity account does not serve {wire}")
        grouped = model in credentials["catalog"]["groups"]
        params = {
            k: v
            for k, v in optional_params.items()
            if k not in ("stream", "stream_options")
            and v is not None
            # Grouped families encode effort in the SKU; LiteLLM rejects xhigh.
            and not (grouped and k == "reasoning_effort")
        }
        mapped = GoogleAIStudioGeminiConfig().map_openai_params(
            non_default_params=params, optional_params={}, model=model, drop_params=True
        )
        schema = mapped.pop("response_json_schema", None)
        if schema is not None:
            # CCA ignores responseJsonSchema and returns fenced, unconstrained text;
            # it enforces the OpenAPI-style responseSchema.
            mapped["response_schema"] = build_vertex_schema(
                parameters=schema, add_property_ordering=True
            )
        # The Gemini transform mutates messages and may synchronously fetch media.
        inlined = await async_inline_remote_media(copy.deepcopy(messages))
        body = _camel_request(
            transform_request_body(
                messages=inlined,
                model=model,
                optional_params=mapped,
                custom_llm_provider="gemini",
                litellm_params={},
                cached_content=None,
            )
        )
        if "systemInstruction" in body:
            body["systemInstruction"]["role"] = "user"
        for content in body["contents"]:
            for part in content.get("parts", []):
                if "functionCall" in part:
                    # CCA uses positional function responses and the literal bypass sentinel.
                    part["functionCall"].pop("id", None)
                    if part.get("thoughtSignature") == ENCODED_SKIP_SIGNATURE:
                        part["thoughtSignature"] = SKIP_SIGNATURE
                if "functionResponse" in part:
                    part["functionResponse"].pop("id", None)
        # agy counts Gemini contents, so system messages are not steps.
        step = max(1, len(body["contents"]))
        if body.get("tools"):
            body.setdefault(
                "toolConfig", {"functionCallingConfig": {"mode": "VALIDATED"}}
            )
            mode = body["toolConfig"].get("functionCallingConfig", {}).get("mode")
            if mode == "NONE":
                # CCA Gemini ignores NONE; withholding tools enforces no calls.
                body.pop("tools")
                body.pop("toolConfig")
            elif mode == "ANY":
                # CCA also ignores ANY unless the tool-only turn is stated in text.
                body["contents"].append(
                    {
                        "role": "user",
                        "parts": [
                            {
                                "text": "TOOL-ONLY TURN. This turn accepts a tool call and nothing else; "
                                "a text reply here is discarded unread and you will be re-prompted. "
                                "Emit the tool call now.\n"
                            }
                        ],
                    }
                )
        generation = body.setdefault("generationConfig", {})
        if generation.get("candidateCount", 1) != 1:
            raise CustomLLMError(400, "Antigravity supports one candidate per request")
        if profile.get("maxOutputTokens"):
            generation["maxOutputTokens"] = profile["maxOutputTokens"]
        thinking = generation.setdefault("thinkingConfig", {"includeThoughts": True})
        if grouped and profile.get("thinkingLevel") is not None:
            level = profile["thinkingLevel"]
            thinking.pop("thinkingBudget", None)
            # agy names LOW/MEDIUM/HIGH and sends other levels (xhigh = 100) as numbers.
            thinking["thinkingLevel"] = {1: "LOW", 2: "MEDIUM", 3: "HIGH"}.get(level, level)
        elif "thinkingLevel" in thinking:
            # CCA's ThinkingLevel enum is uppercase; LiteLLM maps efforts to lowercase.
            thinking["thinkingLevel"] = thinking["thinkingLevel"].upper()
        # A conversation is identified by everything up to its first user turn.
        opening = []
        for message in messages:
            opening.append(message.get("content"))
            if message.get("role") == "user":
                break
        identity = hashlib.sha256(
            json.dumps(opening, ensure_ascii=False).encode()
        ).digest()
        agent, trajectory = (
            str(uuid.UUID(bytes=identity[:16])),
            str(uuid.UUID(bytes=identity[16:])),
        )
        body["sessionId"] = credentials["session_id"]
        labels = {"cascade_id": agent, "last_step_index": str(step - 1)}
        if profile.get("model"):
            labels["model_enum"] = profile["model"]
        labels.update(
            request_id=f"{trajectory}-{sum(m.get('role') == 'assistant' for m in messages)}",
            root_cascade_id=agent,
            trajectory_id=trajectory,
            used_claude="false",
            used_claude_conservative="false",
            used_non_gemini_model="false",
        )
        body["labels"] = labels
        return credentials, {
            "project": credentials["project"],
            "requestId": f"agent/{agent}/{int(time.time() * 1000)}/{trajectory}/{step}",
            "request": body,
            "model": wire,
            "userAgent": "antigravity",
            "requestType": "agent",
        }

    async def _generate(
        self,
        model: str,
        messages: list,
        optional_params: dict,
        timeout: Any = None,
        **kwargs: Any,
    ) -> AsyncIterator:
        credentials, envelope = await self._request(model, messages, optional_params)
        async with httpx.AsyncClient(
            transport=httpx.AsyncHTTPTransport(local_address=IPV4),
            timeout=timeout or 600,
        ) as client:
            async with client.stream(
                "POST",
                f"{ENDPOINT}/v1internal:streamGenerateContent?alt=sse",
                json=envelope,
                headers=_headers(credentials["access_token"]),
            ) as response:
                if response.is_error:
                    await response.aread()
                    _check(response)
                data = []
                async for line in response.aiter_lines():
                    if line.startswith("data:"):
                        data.append(line[5:].lstrip())
                    elif not line and data:
                        payload = json.loads("\n".join(data))
                        data.clear()
                        if "error" in payload:
                            error = payload["error"]
                            raise CustomLLMError(
                                error.get("code", 502), json.dumps(error)
                            )
                        yield payload.get("response", payload), response
                if data:
                    raise CustomLLMError(
                        502, "Antigravity stream ended inside an SSE event"
                    )

    async def astreaming(
        self, model: str, messages: list, logging_obj: Any, **kwargs: Any
    ) -> AsyncIterator:
        parser = ModelResponseIterator(
            streaming_response=None, sync_stream=False, logging_obj=logging_obj
        )
        usage, finish = None, "stop"
        async for raw, _ in self._generate(model=model, messages=messages, **kwargs):
            chunk = parser.chunk_parser(raw)
            if chunk is None:
                continue
            chunk.model = model
            if chunk.usage is not None:
                usage = chunk.usage.model_dump(exclude_none=True)
                chunk.usage = None
            for choice in chunk.choices:
                if choice.delta.tool_calls:
                    finish = "tool_calls"
                elif (
                    any(c.get("finishReason") for c in raw.get("candidates", []))
                    and finish != "tool_calls"
                ):
                    finish = choice.finish_reason or "stop"
                # LiteLLM's Gemini parser sets a reason even on intermediate chunks.
                choice.finish_reason = None
            yield chunk
        if usage is None:
            raise CustomLLMError(502, "Antigravity stream ended without final usage")
        # A ModelResponseStream with an empty finish delta loses its usage in
        # CustomStreamWrapper. The generic terminal chunk preserves it in all bridges.
        yield {
            "text": "",
            "tool_use": None,
            "is_finished": True,
            "finish_reason": finish,
            "usage": usage,
            "index": 0,
        }

    async def acompletion(
        self, model: str, messages: list, logging_obj: Any, **kwargs: Any
    ) -> Any:
        combined, candidates = {}, {}
        raw_response = None
        async for raw, raw_response in self._generate(
            model=model, messages=messages, **kwargs
        ):
            combined.update({k: v for k, v in raw.items() if k != "candidates"})
            for candidate in raw.get("candidates", []):
                target = candidates.setdefault(
                    candidate.get("index", 0),
                    {"content": {"role": "model", "parts": []}},
                )
                target["content"]["parts"].extend(
                    candidate.get("content", {}).get("parts", [])
                )
                target.update({k: v for k, v in candidate.items() if k != "content"})
        if raw_response is None or "usageMetadata" not in combined:
            raise CustomLLMError(502, "Antigravity stream ended without final usage")
        combined["candidates"] = list(candidates.values())
        # Transform only after real usage is known; stream_chunk_builder would
        # otherwise cache an estimated response_cost before usage is overwritten.
        response = VertexGeminiConfig().transform_google_generate_content_to_openai_model_response(
            completion_response=combined,
            model_response=ModelResponse(),
            model=model,
            logging_obj=logging_obj,
            raw_response=raw_response,
        )
        response.model = model
        return response

    def completion(self, **kwargs: Any) -> Any:
        return asyncio.run(self.acompletion(**kwargs))

    def streaming(self, **kwargs: Any) -> Iterator:
        loop = asyncio.new_event_loop()
        stream = self.astreaming(**kwargs)
        try:
            while True:
                try:
                    yield loop.run_until_complete(anext(stream))
                except StopAsyncIteration:
                    return
        finally:
            loop.run_until_complete(stream.aclose())
            loop.run_until_complete(loop.shutdown_asyncgens())
            loop.close()


handler = AntigravityProvider()

if __name__ == "__main__":
    args = sys.argv[1:]
    if args not in (["login"], ["login", "--start"], ["login", "--finish"]):
        raise SystemExit(
            "Usage: python antigravity_provider.py login [--start | --finish]"
        )
    if args != ["login", "--finish"]:
        _start_login()
    if args != ["login", "--start"]:
        _finish_login()
