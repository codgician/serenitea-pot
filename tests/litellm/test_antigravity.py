"""Run with LiteLLM's Python environment: python -m unittest discover -s tests/litellm."""

import asyncio
import importlib.util
import json
import os
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import httpx
import litellm
from litellm.integrations.custom_logger import CustomLogger

HOOK = (
    Path(__file__).resolve().parents[2]
    / "modules/nixos/services/litellm/hooks/antigravity_provider.py"
)
spec = importlib.util.spec_from_file_location("antigravity_test_provider", HOOK)
provider = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provider)

SIGNATURE = "c2lnbmVkLWdlbWluaS1jYWxs"
MODEL = "gemini-3.1-pro-preview"
USAGE = {
    "promptTokenCount": 1000,
    "candidatesTokenCount": 20,
    "thoughtsTokenCount": 30,
    "totalTokenCount": 1050,
    "cachedContentTokenCount": 800,
}


def event(parts, **extra):
    return {
        "response": {
            "responseId": "test-response",
            "modelVersion": MODEL,
            "candidates": [
                {"index": 0, "content": {"role": "model", "parts": parts}, **extra}
            ],
        }
    }


class Accounting(CustomLogger):
    def __init__(self):
        super().__init__()
        self.event = asyncio.Event()
        self.value = None

    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        self.value = kwargs["standard_logging_object"]
        self.event.set()


class AntigravityTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.requests = []
        self.tool = False
        self.failure = False
        self.omit_usage = False
        self.split_event = False
        self.accounting = Accounting()
        self.saved_globals = {
            name: list(getattr(litellm, name))
            for name in (
                "callbacks",
                "custom_provider_map",
                "provider_list",
                "_custom_providers",
                "success_callback",
                "_async_success_callback",
                "failure_callback",
                "_async_failure_callback",
            )
        }
        litellm.callbacks = [self.accounting]
        litellm.custom_provider_map = [
            {"provider": "antigravity", "custom_handler": provider.handler}
        ]
        litellm.utils.custom_llm_setup()
        credentials = {
            "access_token": "test-access",
            "project": "test-project",
            "models": {
                m: {"maxOutputTokens": 65535, "thinkingBudget": 1001}
                for m in ("gemini-3.1-pro-low", "gemini-pro-agent")
            },
        }
        self.credentials_patch = patch.object(
            provider, "_credentials", return_value=credentials
        )
        self.credentials_patch.start()
        client_type = httpx.AsyncClient
        self.client_patch = patch.object(
            provider.httpx,
            "AsyncClient",
            side_effect=lambda **kw: client_type(
                **{**kw, "transport": httpx.MockTransport(self.upstream)}
            ),
        )
        self.client_patch.start()
        self.router = litellm.Router(
            model_list=[
                {
                    "model_name": "antigravity-test",
                    "litellm_params": {
                        "model": f"antigravity/{MODEL}",
                        "allowed_openai_params": ["reasoning_effort"],
                    },
                    "model_info": {
                        "mode": "chat",
                        "reasoning_effort_levels": ["low", "high"],
                        "input_cost_per_token": 2e-6,
                        "output_cost_per_token": 12e-6,
                        "cache_read_input_token_cost": 0.2e-6,
                        "antigravity": {
                            "routes": {
                                "low": "gemini-3.1-pro-low",
                                "high": "gemini-pro-agent",
                            }
                        },
                    },
                }
            ],
            num_retries=0,
        )
        self.addCleanup(self.credentials_patch.stop)
        self.addCleanup(self.client_patch.stop)

    async def asyncTearDown(self):
        for name, value in self.saved_globals.items():
            setattr(litellm, name, value)

    def upstream(self, request):
        self.requests.append(json.loads(request.content))
        parts = [{"text": "Hello"}]
        if self.tool:
            parts = [
                {
                    "functionCall": {"name": "lookup", "args": {"city_name": "Paris"}},
                    "thoughtSignature": SIGNATURE,
                }
            ]
        events = [
            event([{"thought": True, "text": "Checking."}]),
            event(parts),
            event([], finishReason="STOP"),
        ]
        if self.failure:
            events[-1] = {
                "error": {
                    "code": 429,
                    "status": "RESOURCE_EXHAUSTED",
                    "message": "quota exhausted",
                }
            }
        elif not self.omit_usage:
            events[-1]["response"]["usageMetadata"] = USAGE
        chunks = []
        for item in events:
            data = json.dumps(item)
            if self.split_event:
                data = data.replace(', "modelVersion"', ',\n"modelVersion"')
            chunks.append(
                "\n".join("data: " + line for line in data.splitlines()) + "\n\n"
            )
        return httpx.Response(
            200, headers={"Content-Type": "text/event-stream"}, content="".join(chunks)
        )

    async def complete(self, **kw):
        return await self.router.acompletion(
            model="antigravity-test", messages=[{"role": "user", "content": "Hi"}], **kw
        )

    async def assert_accounting(self):
        await asyncio.wait_for(self.accounting.event.wait(), 5)
        self.assertAlmostEqual(self.accounting.value["response_cost"], 0.00116)
        usage = self.accounting.value["metadata"]["usage_object"]
        self.assertEqual(usage["prompt_tokens"], 1000)
        self.assertEqual(usage["completion_tokens"], 50)
        self.assertEqual(usage["prompt_tokens_details"]["cached_tokens"], 800)
        self.assertEqual(usage["completion_tokens_details"]["reasoning_tokens"], 30)

    async def test_stream_preserves_thoughts_cache_usage_and_accounting(self):
        stream = await self.complete(
            stream=True, stream_options={"include_usage": True}, reasoning_effort="high"
        )
        chunks = [c async for c in stream]
        self.assertEqual(
            "".join(
                getattr(c.choices[0].delta, "reasoning_content", None) or ""
                for c in chunks
                if c.choices
            ),
            "Checking.",
        )
        self.assertEqual(
            "".join(c.choices[0].delta.content or "" for c in chunks if c.choices),
            "Hello",
        )
        usage = next(c.usage for c in reversed(chunks) if c.usage)
        self.assertEqual(usage.prompt_tokens_details.cached_tokens, 800)
        self.assertEqual(usage.completion_tokens_details.reasoning_tokens, 30)
        self.assertEqual(self.requests[0]["model"], "gemini-pro-agent")
        await self.assert_accounting()

    async def test_nonstream_does_not_cache_estimated_cost(self):
        response = await self.complete()
        self.assertEqual(response.choices[0].message.content, "Hello")
        self.assertEqual(response.usage.prompt_tokens, 1000)
        self.assertEqual(response.usage.completion_tokens, 50)
        await self.assert_accounting()

    async def test_tool_signature_and_argument_names_survive_round_trip(self):
        self.tool = True
        tools = [
            {
                "type": "function",
                "function": {
                    "name": "lookup",
                    "parameters": {
                        "type": "object",
                        "properties": {"city_name": {"type": "string"}},
                        "required": ["city_name"],
                    },
                },
            }
        ]
        response = await self.complete(tools=tools)
        message = response.choices[0].message.model_dump(exclude_none=True)
        call = message["tool_calls"][0]
        self.assertEqual(
            json.loads(call["function"]["arguments"]), {"city_name": "Paris"}
        )
        self.tool = False
        response = await self.router.acompletion(
            model="antigravity-test",
            messages=[
                {"role": "user", "content": "Hi"},
                message,
                {"role": "tool", "tool_call_id": call["id"], "content": "18 C"},
            ],
            tools=tools,
        )
        parts = [
            p for c in self.requests[-1]["request"]["contents"] for p in c["parts"]
        ]
        invocation = next(p for p in parts if "functionCall" in p)
        self.assertEqual(invocation["thoughtSignature"], SIGNATURE)
        self.assertEqual(invocation["functionCall"]["args"], {"city_name": "Paris"})
        self.assertNotIn("id", invocation["functionCall"])
        self.assertEqual(response.choices[0].message.content, "Hello")

    async def test_sse_multiline_data_is_one_json_event(self):
        self.split_event = True
        response = await self.complete()
        self.assertEqual(response.choices[0].message.content, "Hello")
        self.assertEqual(response.usage.prompt_tokens_details.cached_tokens, 800)

    async def test_missing_usage_is_not_silently_estimated(self):
        self.omit_usage = True
        log = SimpleNamespace(optional_params={}, litellm_params={})
        with self.assertRaisesRegex(provider.CustomLLMError, "without final usage"):
            async for _ in provider.handler.astreaming(
                model=MODEL,
                messages=[{"role": "user", "content": "Hi"}],
                optional_params={},
                litellm_params={
                    "model_info": {
                        "antigravity": {"routes": {"low": "gemini-3.1-pro-low"}}
                    }
                },
                logging_obj=log,
            ):
                pass

    async def test_tool_choice_none_withholds_declarations(self):
        response = await self.complete(
            tools=[
                {
                    "type": "function",
                    "function": {
                        "name": "lookup",
                        "parameters": {
                            "type": "object",
                            "properties": {"city": {"type": "string"}},
                        },
                    },
                }
            ],
            tool_choice="none",
        )
        self.assertEqual(response.choices[0].message.content, "Hello")
        self.assertNotIn("tools", self.requests[0]["request"])

    async def test_json_schema_uses_enforced_response_schema(self):
        await self.complete(
            response_format={
                "type": "json_schema",
                "json_schema": {
                    "name": "person",
                    "strict": True,
                    "schema": {
                        "type": "object",
                        "properties": {"who": {"$ref": "#/$defs/name"}},
                        "required": ["who"],
                        "additionalProperties": False,
                        "$defs": {"name": {"type": "string"}},
                    },
                },
            }
        )
        generation = self.requests[0]["request"]["generationConfig"]
        # Measured: CCA ignores responseJsonSchema and returns fenced free text.
        self.assertNotIn("responseJsonSchema", generation)
        self.assertEqual(generation["responseMimeType"], "application/json")
        self.assertEqual(
            generation["responseSchema"],
            {
                "type": "object",
                "properties": {"who": {"type": "string"}},
                "required": ["who"],
                "propertyOrdering": ["who"],
            },
        )

    async def test_midstream_error_does_not_emit_successful_finish(self):
        self.failure = True
        log = SimpleNamespace(optional_params={}, litellm_params={})
        with self.assertRaises(provider.CustomLLMError) as error:
            async for _ in provider.handler.astreaming(
                model=MODEL,
                messages=[{"role": "user", "content": "Hi"}],
                optional_params={},
                litellm_params={
                    "model_info": {
                        "antigravity": {"routes": {"low": "gemini-3.1-pro-low"}}
                    }
                },
                logging_obj=log,
            ):
                pass
        self.assertEqual(error.exception.status_code, 429)


class ProjectEligibilityTests(unittest.TestCase):
    def test_paid_project_remains_usable_when_free_tier_is_region_blocked(self):
        # Observed loadCodeAssist response: current standard-tier and paid Ultra
        # coexist with UNSUPPORTED_LOCATION for free-tier only.
        response = {
            "cloudaicompanionProject": "paid-project",
            "currentTier": {"id": "standard-tier"},
            "paidTier": {"id": "g1-ultra-lite-tier"},
            "allowedTiers": [{"id": "standard-tier"}],
            "ineligibleTiers": [
                {
                    "tierId": "free-tier",
                    "reasonCode": "UNSUPPORTED_LOCATION",
                    "reasonMessage": "not available in your location",
                }
            ],
        }
        with patch.object(provider, "_control", return_value=response):
            self.assertEqual(provider._project("test-access"), "paid-project")

    def test_free_tier_region_rejection_still_blocks_new_onboarding(self):
        response = {
            "allowedTiers": [],
            "ineligibleTiers": [
                {
                    "tierId": "free-tier",
                    "reasonMessage": "not available in your location",
                }
            ],
        }
        with patch.object(provider, "_control", return_value=response):
            with self.assertRaisesRegex(
                provider.CustomLLMError, "not available in your location"
            ):
                provider._project("test-access")


class CredentialTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        env_patch = patch.dict(
            os.environ,
            ANTIGRAVITY_TOKEN_DIR=self.directory.name,
            ANTIGRAVITY_OAUTH_CLIENT_ID="test-client.apps.googleusercontent.com",
            ANTIGRAVITY_OAUTH_CLIENT_SECRET="test-client-secret",
        )
        env_patch.start()
        self.addCleanup(env_patch.stop)
        self.path = provider._credential_path()
        provider._save(
            self.path,
            {
                "refresh_token": "old-refresh",
                "access_token": "old-access",
                "expires_at": 0,
                "project": "test-project",
                "models": {},
            },
        )

    def test_concurrent_workers_refresh_only_once(self):
        with patch.object(
            provider,
            "_token",
            return_value={
                "access_token": "new-access",
                "refresh_token": "new-refresh",
                "expires_in": 3600,
            },
        ) as token:
            with patch.object(
                provider,
                "_control",
                return_value={"models": {MODEL: {"maxOutputTokens": 65535}}},
            ):
                with ThreadPoolExecutor(max_workers=2) as workers:
                    results = list(
                        workers.map(lambda _: provider._credentials(), range(2))
                    )
        self.assertEqual(token.call_count, 1)
        self.assertEqual(
            [r["refresh_token"] for r in results], ["new-refresh", "new-refresh"]
        )
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_catalog_failure_does_not_lose_rotated_refresh_token(self):
        with patch.object(
            provider,
            "_token",
            return_value={
                "access_token": "new-access",
                "refresh_token": "new-refresh",
                "expires_in": 3600,
            },
        ):
            with patch.object(
                provider,
                "_control",
                side_effect=provider.CustomLLMError(503, "catalog unavailable"),
            ):
                with self.assertRaises(provider.CustomLLMError):
                    provider._credentials()
        saved = json.loads(self.path.read_text())
        self.assertEqual(saved["refresh_token"], "new-refresh")
        self.assertEqual(saved["access_token"], "new-access")

    def test_shared_readable_credentials_are_rejected(self):
        self.path.chmod(0o644)
        with self.assertRaisesRegex(provider.CustomLLMError, "mode 0600"):
            provider._credentials()

    def test_wrong_oauth_state_cannot_replace_credentials(self):
        provider._save(
            self.path.parent / ".oauth.json",
            {"state": "expected", "verifier": "private-verifier"},
        )
        before = self.path.read_bytes()
        with patch(
            "builtins.input",
            return_value="http://127.0.0.1:51121/oauth-callback?state=wrong&code=test",
        ):
            with self.assertRaisesRegex(ValueError, "state mismatch"):
                provider._finish_login()
        self.assertEqual(self.path.read_bytes(), before)

    def test_project_rejection_preserves_tokens_and_can_resume_without_reusing_code(
        self,
    ):
        pending_path = self.path.parent / ".oauth.json"
        provider._save(
            pending_path, {"state": "expected", "verifier": "private-verifier"}
        )
        before = self.path.read_bytes()
        tokens = {
            "access_token": "new-access",
            "refresh_token": "new-refresh",
            "expires_in": 3600,
        }
        with patch(
            "builtins.input",
            return_value="http://127.0.0.1:51121/oauth-callback?state=expected&code=single-use",
        ):
            with patch.object(provider, "_token", return_value=tokens):
                with patch.object(
                    provider,
                    "_project",
                    side_effect=provider.CustomLLMError(
                        403, "not available in your location"
                    ),
                ):
                    with self.assertRaisesRegex(
                        provider.CustomLLMError, "not available in your location"
                    ):
                        provider._finish_login()
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(
            json.loads(pending_path.read_text())["tokens"]["refresh_token"],
            "new-refresh",
        )
        self.assertEqual(pending_path.stat().st_mode & 0o777, 0o600)
        with patch(
            "builtins.input",
            side_effect=AssertionError("must not request a consumed code"),
        ):
            with patch.object(
                provider,
                "_token",
                side_effect=AssertionError("fresh access token must be reused"),
            ):
                with patch.object(provider, "_project", return_value="test-project"):
                    with patch.object(
                        provider,
                        "_control",
                        return_value={"models": {MODEL: {"maxOutputTokens": 65535}}},
                    ):
                        provider._finish_login()
        self.assertFalse(pending_path.exists())
        self.assertEqual(
            json.loads(self.path.read_text())["refresh_token"], "new-refresh"
        )

    def test_pending_login_retains_rotated_token_if_project_retry_fails(self):
        pending_path = self.path.parent / ".oauth.json"
        provider._save(
            pending_path,
            {
                "tokens": {"access_token": "expired", "refresh_token": "old-refresh"},
                "expires_at": 0,
            },
        )
        with patch.object(
            provider,
            "_token",
            return_value={
                "access_token": "renewed",
                "refresh_token": "rotated",
                "expires_in": 3600,
            },
        ):
            with patch.object(
                provider,
                "_project",
                side_effect=provider.CustomLLMError(503, "project unavailable"),
            ):
                with self.assertRaises(provider.CustomLLMError):
                    provider._finish_login()
        self.assertEqual(
            json.loads(pending_path.read_text())["tokens"]["refresh_token"], "rotated"
        )


if __name__ == "__main__":
    unittest.main()
