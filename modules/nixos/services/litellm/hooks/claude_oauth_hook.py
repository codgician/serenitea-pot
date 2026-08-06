from __future__ import annotations

from typing import Any

from litellm.integrations.custom_logger import CustomLogger
from litellm.types.utils import CallTypes


IDENTITY = "You are a Claude agent, built on Anthropic's Claude Agent SDK."
VALID_IDENTITIES = {
    IDENTITY,
    "You are Claude Code, Anthropic's official CLI for Claude.",
}
BILLING_PREFIX = "x-anthropic-billing-header:"
NATIVE_CALLS = {CallTypes.anthropic_messages.value, CallTypes.aanthropic_messages.value}
RESPONSES_CALLS = {CallTypes.responses.value, CallTypes.aresponses.value}
CHAT_CALLS = {CallTypes.completion.value, CallTypes.acompletion.value}
SUPPORTED_CALLS = NATIVE_CALLS | RESPONSES_CALLS | CHAT_CALLS


def _first_text(value: Any) -> str | None:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, dict):
        return _first_text(value.get("text") or value.get("content"))
    if isinstance(value, list):
        for item in value:
            if text := _first_text(item):
                return text
    return None


def _first_message_system(messages: Any) -> str | None:
    if not isinstance(messages, list):
        return None
    return next(
        (
            _first_text(message.get("content"))
            for message in messages
            if isinstance(message, dict) and message.get("role") in {"system", "developer"}
        ),
        None,
    )


def _has_identity(data: dict, call_type: str) -> bool:
    if call_type in NATIVE_CALLS:
        text = _first_text(data.get("system"))
    elif call_type in RESPONSES_CALLS:
        text = _first_text(data.get("instructions")) or _first_message_system(data.get("input"))
    else:
        text = _first_message_system(data.get("messages"))
    return text in VALID_IDENTITIES or bool(text and text.startswith(BILLING_PREFIX))


def _inject_native(data: dict) -> None:
    identity = {"type": "text", "text": IDENTITY}
    system = data.get("system")
    if isinstance(system, list):
        system.insert(0, identity)
    elif isinstance(system, str) and system:
        data["system"] = [identity, {"type": "text", "text": system}]
    else:
        data["system"] = [identity]


def _inject_responses(data: dict) -> None:
    input_value = data.get("input")
    input_items = (
        input_value
        if isinstance(input_value, list)
        else [{"role": "user", "content": input_value}] if isinstance(input_value, str) else []
    )
    prefix = [{"role": "system", "content": IDENTITY}]
    if instructions := data.pop("instructions", None):
        prefix.append({"role": "system", "content": instructions})
    data["input"] = prefix + input_items


class ClaudeOAuthIdentityHook(CustomLogger):
    async def async_pre_call_deployment_hook(self, data: dict, call_type: Any) -> dict | None:
        params = data.get("litellm_params") or {}
        provider = data.get("custom_llm_provider") or params.get("custom_llm_provider")
        if provider != "anthropic" or "haiku" in str(data.get("model", "")).lower():
            return None

        call_type = getattr(call_type, "value", call_type)
        if call_type not in SUPPORTED_CALLS or _has_identity(data, call_type):
            return None

        if call_type in NATIVE_CALLS:
            _inject_native(data)
        elif call_type in RESPONSES_CALLS:
            _inject_responses(data)
        else:
            data["messages"].insert(0, {"role": "system", "content": IDENTITY})
        return data


proxy_handler_instance = ClaudeOAuthIdentityHook()
