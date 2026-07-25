#!/usr/bin/env bash
set -euo pipefail

provider_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output="$provider_dir/models.json"
models_url="https://api.githubcopilot.com/models"
token_url="https://api.github.com/copilot_internal/v2/token"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl_args=(--fail-with-body --retry 3 --silent --show-error)

fetch_models() {
  local token="$1"
  local integration_id="$2"
  curl "${curl_args[@]}" \
    -H "Accept: application/json" \
    -H "Copilot-Integration-Id: $integration_id" \
    -H "Authorization: Bearer $token" \
    -H "X-GitHub-Api-Version: 2026-06-01" \
    "$models_url" >"$tmp/models.json"
}

if [[ -n "${COPILOT_MODELS_FILE:-}" ]]; then
  cp "$COPILOT_MODELS_FILE" "$tmp/models.json"
else
  : "${COPILOT_GITHUB_TOKEN:?COPILOT_GITHUB_TOKEN is required}"
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    fetch_models "$COPILOT_GITHUB_TOKEN" "agentic-workflows"
  else
    copilot_token="$(curl "${curl_args[@]}" \
      -H "Accept: application/json" \
      -H "Copilot-Integration-Id: vscode-chat" \
      -H "User-Agent: serenitea-pot-model-refresh" \
      -H "Authorization: Bearer $COPILOT_GITHUB_TOKEN" \
      "$token_url" | jq -er .token)"
    fetch_models "$copilot_token" "vscode-chat"
  fi
fi

jq -Se '
  def endpoints($model):
    [($model.supported_endpoints // [])[]
      | select(startswith("/"))
      | if startswith("/v1/") then . else "/v1" + . end];
  def mode($model):
    ($model.capabilities.type // "chat") as $type
    | if $type == "embeddings" then "embedding"
      elif $type != "chat" then $type
      elif (($model.supported_endpoints // []) | index("/responses")) != null
        and (($model.supported_endpoints // []) | index("/chat/completions")) == null
      then "responses"
      else "chat"
      end;
  def reasoning($model):
    ($model.capabilities.supports // {}) as $supports
    | (($supports.reasoning_effort // []) | length) > 0
      or $supports.adaptive_thinking == true
      or $supports.max_thinking_budget != null
      or $supports.reasoning == true
      or $supports.thinking == true;
  def vision($model):
    $model.capabilities.supports.vision == true
    or (([($model.capabilities.limits.vision.supported_media_types // [])[]
      | select(startswith("image/"))] | length) > 0);
  def rates($tier; $factor): {
    input: (($tier.input_price // 0) * $factor),
    output: (($tier.output_price // 0) * $factor),
    cacheRead: (($tier.cache_price // 0) * $factor),
    cacheWrite: (($tier.cache_write_price // 0) * $factor)
  };
  def cost($model):
    ($model.billing.token_prices // {}) as $prices
    | ($prices.batch_size // 0) as $batch
    | if $batch <= 0 then {}
      else
        (10000 / $batch) as $factor
        | { cost: (
            rates($prices.default; $factor)
            + if $prices.long_context == null then {}
              else { tiers: [
                rates($prices.long_context; $factor)
                + { inputTokensAbove: $prices.default.context_max }
              ] } end
          ) }
      end;
  if (.data | type) != "array" then
    error("Copilot /models response has no data array")
  else
    [.data[]
      | select((.model_picker_enabled == true or .capabilities.type == "embeddings")
        and .policy.state != "disabled")]
    | sort_by(.id)
    | reduce .[] as $model ({};
        ($model.capabilities.limits // {}) as $limits
        | ($model.capabilities.supports // {}) as $supports
        | .[$model.id] = ({
            mode: mode($model),
            reasoningEfforts: ($supports.reasoning_effort // []),
            supportedEndpoints: endpoints($model),
            supports: [
              (if $supports.tool_calls == true then "toolCalls" else empty end),
              (if $supports.parallel_tool_calls == true then "parallelToolCalls" else empty end),
              (if $supports.structured_outputs == true then "structuredOutputs" else empty end),
              (if vision($model) then "vision" else empty end),
              (if reasoning($model) then "reasoning" else empty end)
            ]
          }
          + if $limits.max_context_window_tokens == null then {}
            else { contextWindow: $limits.max_context_window_tokens } end
          + if $limits.max_prompt_tokens == null then {}
            else { maxInputTokens: $limits.max_prompt_tokens } end
          + if $limits.max_output_tokens == null then {}
            else { maxOutputTokens: $limits.max_output_tokens } end
          + cost($model))
      )
  end
' "$tmp/models.json" >"$tmp/output.json"

count="$(jq 'length' "$tmp/output.json")"
priced="$(jq '[.[] | select(.cost != null)] | length' "$tmp/output.json")"
echo "github-copilot: $count models, $priced priced" >&2

if cmp -s "$tmp/output.json" "$output"; then
  echo "github-copilot: unchanged" >&2
elif [[ "${CHECK_MODE:-0}" == 1 ]]; then
  echo "github-copilot: stale ($output)" >&2
  exit 1
else
  mv "$tmp/output.json" "$output"
  echo "github-copilot: updated $output" >&2
fi
