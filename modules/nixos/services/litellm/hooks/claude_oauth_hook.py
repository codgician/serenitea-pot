from __future__ import annotations

from typing import Any

from litellm.integrations.custom_guardrail import CustomGuardrail
from litellm.types.guardrails import GuardrailEventHooks
from litellm.types.utils import CallTypes


GUARDRAIL_NAME = "claude_oauth_hook"
IDENTITY = "You are a Claude agent, built on Anthropic's Claude Agent SDK."
VALID_IDENTITIES = {
    IDENTITY,
    "You are Claude Code, Anthropic's official CLI for Claude.",
}
BILLING_PREFIX = "x-anthropic-billing-header:"
MESSAGES_CALLS = {CallTypes.anthropic_messages.value, CallTypes.aanthropic_messages.value}
RESPONSES_CALLS = {CallTypes.responses.value, CallTypes.aresponses.value}
CHAT_COMPLETION_CALLS = {CallTypes.completion.value, CallTypes.acompletion.value}


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


def _is_valid_identity(text: str | None) -> bool:
    return text in VALID_IDENTITIES or bool(text and text.startswith(BILLING_PREFIX))


def _inject_messages(data: dict) -> bool:
    system = data.get("system")
    if _is_valid_identity(_first_text(system)):
        return False

    identity = {"type": "text", "text": IDENTITY}
    if isinstance(system, list):
        system.insert(0, identity)
    elif isinstance(system, str):
        data["system"] = [identity]
        if system:
            data["system"].append({"type": "text", "text": system})
    elif system is None:
        data["system"] = [identity]
    else:
        return False
    return True


def _inject_responses(data: dict) -> bool:
    input_value = data.get("input")
    identity = _first_text(data.get("instructions")) or _first_message_system(input_value)
    if _is_valid_identity(identity):
        return False

    if isinstance(input_value, list):
        input_items = input_value
    elif isinstance(input_value, str):
        input_items = [{"role": "user", "content": input_value}]
    elif input_value is None:
        input_items = []
    else:
        return False

    prefix = [{"role": "system", "content": IDENTITY}]
    if instructions := data.pop("instructions", None):
        prefix.append({"role": "system", "content": instructions})
    data["input"] = prefix + input_items
    return True


def _inject_chat_completions(data: dict) -> bool:
    messages = data.get("messages")
    if not isinstance(messages, list) or _is_valid_identity(_first_message_system(messages)):
        return False
    messages.insert(0, {"role": "system", "content": IDENTITY})
    return True


class ClaudeOAuthIdentityHook(CustomGuardrail):
    def __init__(self) -> None:
        super().__init__(
            guardrail_name=GUARDRAIL_NAME,
            supported_event_hooks=[GuardrailEventHooks.pre_call],
            event_hook=GuardrailEventHooks.pre_call,
            default_on=False,
        )

    async def async_pre_call_hook(
        self,
        user_api_key_dict: Any,
        cache: Any,
        data: dict,
        call_type: Any,
    ) -> dict | None:
        call_type = getattr(call_type, "value", call_type)
        if call_type in MESSAGES_CALLS:
            injected = _inject_messages(data)
        elif call_type in RESPONSES_CALLS:
            injected = _inject_responses(data)
        elif call_type in CHAT_COMPLETION_CALLS:
            injected = _inject_chat_completions(data)
        else:
            return None
        return data if injected else None


proxy_handler_instance = ClaudeOAuthIdentityHook()
