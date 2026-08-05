#!/usr/bin/env bash
set -euo pipefail

provider_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output="$provider_dir/models.json"
models_url="https://api.anthropic.com/v1/models?limit=1000"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [[ -n "${CLAUDE_MODELS_FILE:-}" ]]; then
  cp "$CLAUDE_MODELS_FILE" "$tmp/models.json"
else
  : "${CLAUDE_OAUTH_API_KEY:?CLAUDE_OAUTH_API_KEY is required}"
  curl --fail-with-body --retry 3 --silent --show-error \
    -H "Authorization: Bearer $CLAUDE_OAUTH_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "$models_url" >"$tmp/models.json"
fi

jq -Se '
  def supported($capability): $capability.supported == true;
  def reasoning_efforts($model):
    ["low", "medium", "high", "xhigh", "max"]
    | map(select(supported($model.capabilities.effort[.])));
  def undated_id: sub("-[0-9]{8}$"; "");
  def normalized_id:
    undated_id
    | if test("^claude-[^-]+-[0-9]+-[0-9]+$") then
        capture("^(?<prefix>claude-[^-]+-[0-9]+)-(?<minor>[0-9]+)$")
        | "\(.prefix).\(.minor)"
      else . end;
  if (.data | type) != "array" then
    error("Anthropic /models response has no data array")
  elif any(.data[]; (.id | type) != "string"
    or (.max_input_tokens | type) != "number"
    or (.max_tokens | type) != "number") then
    error("Anthropic /models response contains an invalid model")
  else
    [.data[] | select(.type == "model") | { model: ., name: (.id | normalized_id) }] as $models
    | if ($models | length) != ($models | map(.name) | unique | length) then
        error("Anthropic model names collide after normalization")
      else
        reduce $models[] as $entry ({};
          .[$entry.name] = {
            aliases: ([$entry.model.id, ($entry.model.id | undated_id)] | unique | map(select(. != $entry.name))),
            contextWindow: $entry.model.max_input_tokens,
            maxInputTokens: $entry.model.max_input_tokens,
            maxOutputTokens: $entry.model.max_tokens,
            mode: "chat",
            path: $entry.model.id,
            reasoningEfforts: reasoning_efforts($entry.model),
            supportedEndpoints: ["/v1/messages"],
            supports: [
              "toolCalls",
              "parallelToolCalls",
              (if supported($entry.model.capabilities.structured_outputs) then "structuredOutputs" else empty end),
              (if supported($entry.model.capabilities.image_input) or supported($entry.model.capabilities.pdf_input) then "vision" else empty end),
              (if supported($entry.model.capabilities.thinking) then "reasoning" else empty end)
            ]
          }
        )
      end
  end
' "$tmp/models.json" >"$tmp/output.json"

count="$(jq 'length' "$tmp/output.json")"
echo "claude: $count models" >&2

if cmp -s "$tmp/output.json" "$output"; then
  echo "claude: unchanged" >&2
elif [[ "${CHECK_MODE:-0}" == 1 ]]; then
  echo "claude: stale ($output)" >&2
  exit 1
else
  mv "$tmp/output.json" "$output"
  echo "claude: updated $output" >&2
fi
