from __future__ import annotations

import os
from typing import Any

from litellm.integrations.custom_logger import CustomLogger
from litellm.types.utils import CallTypes


CLAUDE_SDK_IDENTITY = "You are a Claude agent, built on Anthropic's Claude Agent SDK."
CLAUDE_CODE_IDENTITY = "You are Claude Code, Anthropic's official CLI for Claude."
VALID_IDENTITIES = {
    CLAUDE_SDK_IDENTITY,
    CLAUDE_CODE_IDENTITY,
}
BILLING_PREFIX = "x-anthropic-billing-header:"
MESSAGES_CALLS = {CallTypes.anthropic_messages.value, CallTypes.aanthropic_messages.value}
RESPONSES_CALLS = {CallTypes.responses.value, CallTypes.aresponses.value}
CHAT_COMPLETION_CALLS = {CallTypes.completion.value, CallTypes.acompletion.value}
SYSTEM_ROLES = frozenset({"system", "developer"})
TEXT_BLOCK_TYPES = frozenset({"text", "input_text"})


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


def _inject_identity(data: dict, call_type: str) -> dict | None:
    if call_type in MESSAGES_CALLS:
        field = "system"
    elif call_type in RESPONSES_CALLS:
        field = "input"
    elif call_type in CHAT_COMPLETION_CALLS:
        field = "messages"
    else:
        return None

    value = data.get(field)
    text = _first_text(value) if field == "system" else None
    if field == "input":
        text = _first_text(data.get("instructions"))
    if field != "system" and not text and isinstance(value, list):
        text = next(
            (
                _first_text(message.get("content"))
                for message in value
                if isinstance(message, dict) and message.get("role") in {"system", "developer"}
            ),
            None,
        )
    if text in VALID_IDENTITIES or (text and text.startswith(BILLING_PREFIX)):
        return None

    if field == "system":
        prefix = [{"type": "text", "text": CLAUDE_SDK_IDENTITY}]
        if isinstance(value, str):
            value = [{"type": "text", "text": value}] if value else []
    else:
        prefix = [{"role": "system", "content": CLAUDE_SDK_IDENTITY}]
        if field == "input" and isinstance(value, str):
            value = [{"role": "user", "content": value}]
    if value is None and field != "messages":
        value = []
    if not isinstance(value, list):
        return None

    result = data.copy()
    if field == "input" and (instructions := result.pop("instructions", None)):
        prefix.append({"role": "system", "content": instructions})
    result[field] = prefix + value
    return result


def _without_claude_code_identity(content: Any, *, messages: bool = False) -> Any:
    """Filter system content or system-role messages, copying only on a change."""
    if isinstance(content, str) and not messages:
        return "" if content.strip() == CLAUDE_CODE_IDENTITY else content
    if not isinstance(content, list):
        return content

    field, kinds = ("role", SYSTEM_ROLES) if messages else ("type", TEXT_BLOCK_TYPES)
    result = None
    start = 0
    for index, item in enumerate(content):
        if not isinstance(item, dict) or item.get(field) not in kinds:
            continue
        if messages:
            filtered = _without_claude_code_identity(item.get("content"))
            if filtered is item.get("content"):
                continue
            replacement = {**item, "content": filtered} if filtered else None
        else:
            if item.get("text", "").strip() != CLAUDE_CODE_IDENTITY:
                continue
            replacement = None
        if result is None:
            result = []
        result.extend(content[start:index])
        if replacement is not None:
            result.append(replacement)
        start = index + 1
    if result is None:
        return content
    result.extend(content[start:])
    return result


def _strip_claude_code_beta(headers: dict[str, str]) -> dict[str, str]:
    filtered = headers
    for name, value in headers.items():
        if name.lower() != "anthropic-beta" or "claude-code-20250219" not in value:
            continue
        parts = value.split(",")
        remaining = [beta for beta in map(str.strip, parts) if beta != "claude-code-20250219"]
        if len(remaining) == len(parts):
            continue
        if filtered is headers:
            filtered = headers.copy()
        if remaining:
            filtered[name] = ",".join(remaining)
        else:
            del filtered[name]
    return filtered


class ClaudeOAuthIdentityHook(CustomLogger):
    """Apply credential-specific identity and beta handling after selection.

    API-key requests omit the Claude Code beta and exact system identity blocks.
    Other instructions and cache controls are preserved; OAuth logic is unchanged.
    This transport policy does not change Anthropic's credit-eligibility terms.

    Transformations are copy-on-write: unchanged requests return None, and
    edited requests share untouched content without mutating retry/fallback input.
    """

    async def async_pre_call_deployment_hook(
        self, kwargs: dict[str, Any], call_type: CallTypes | None
    ) -> dict | None:
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if api_key and kwargs.get("api_key") == api_key:
            data = kwargs
            for field in ("system", "instructions", "messages", "input"):
                value = kwargs.get(field)
                content = _without_claude_code_identity(
                    value, messages=field in ("messages", "input")
                )
                if content is value:
                    continue
                if data is kwargs:
                    data = kwargs.copy()
                if content or field in ("messages", "input"):
                    data[field] = content
                else:
                    data.pop(field)

            # SDK and proxy requests use different header carriers.
            provider = kwargs.get("provider_specific_header")
            for field, carrier in (("extra_headers", kwargs), ("provider_specific_header", provider)):
                if not carrier or not (headers := carrier.get("extra_headers")):
                    continue
                filtered = _strip_claude_code_beta(headers)
                if filtered is headers:
                    continue
                if data is kwargs:
                    data = kwargs.copy()
                data[field] = filtered if carrier is kwargs else {**carrier, "extra_headers": filtered}
            return None if data is kwargs else data

        token = os.environ.get("CLAUDE_CODE_OAUTH_TOKEN")
        if not token or kwargs.get("api_key") != token:
            return None

        return _inject_identity(kwargs, getattr(call_type, "value", call_type))


proxy_handler_instance = ClaudeOAuthIdentityHook()
