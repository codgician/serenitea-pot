#!/usr/bin/env bash
set -euo pipefail

provider_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output="$provider_dir/models.json"
models_url="https://generativelanguage.googleapis.com/v1beta/models"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [[ -n "${GEMINI_MODELS_FILE:-}" ]]; then
  cp "$GEMINI_MODELS_FILE" "$tmp/models.json"
else
  : "${GEMINI_API_KEY:?GEMINI_API_KEY is required}"
  echo '{"models": []}' >"$tmp/models.json"
  page_token=""
  while :; do
    page_args=(--data-urlencode "pageSize=1000")
    [[ -z "$page_token" ]] || page_args+=(--data-urlencode "pageToken=$page_token")
    curl --fail-with-body --retry 3 --silent --show-error --get \
      -H "x-goog-api-key: $GEMINI_API_KEY" \
      "${page_args[@]}" \
      "$models_url" >"$tmp/page.json"
    jq -s '{models: (.[0].models + (.[1].models // []))}' \
      "$tmp/models.json" "$tmp/page.json" >"$tmp/merged.json"
    mv "$tmp/merged.json" "$tmp/models.json"
    page_token="$(jq -r '.nextPageToken // empty' "$tmp/page.json")"
    [[ -n "$page_token" ]] || break
  done
fi

# The list does not say which models only emit images, audio or other media, so
# keep Gemini text models by name; the provider lists image models itself.
# Current Gemini text models all take images and call tools; the list reports
# only whether a model thinks. LiteLLM maps efforts to thinking levels and
# accepts `minimal` on flash models only.
jq -Se '
  def text_model:
    (.name | ltrimstr("models/")) as $id
    | ($id | startswith("gemini-"))
      and ((.supportedGenerationMethods // []) | index("generateContent")) != null
      and ($id | test("image|tts|transcribe|robotics|computer-use|customtools|omni|nano-banana|-latest$") | not);
  def efforts($id):
    (if $id | test("flash") then ["minimal"] else [] end) + ["low", "medium", "high"];
  if (.models | type) != "array" then
    error("Gemini /models response has no models array")
  else
    [.models[] | select(text_model)]
    | if length == 0 then error("Gemini /models response has no text models") else . end
    | reduce .[] as $model ({};
        ($model.name | ltrimstr("models/")) as $id
        | .[$id] = ({
            mode: "chat",
            reasoningEfforts: (if $model.thinking == true then efforts($id) else [] end),
            supports: [
              "toolCalls",
              "parallelToolCalls",
              "structuredOutputs",
              "vision",
              (if $model.thinking == true then "reasoning" else empty end)
            ]
          }
          + if $model.inputTokenLimit == null then {}
            else { contextWindow: $model.inputTokenLimit, maxInputTokens: $model.inputTokenLimit } end
          + if $model.outputTokenLimit == null then {}
            else { maxOutputTokens: $model.outputTokenLimit } end)
      )
  end
' "$tmp/models.json" >"$tmp/output.json"

count="$(jq 'length' "$tmp/output.json")"
echo "google: $count models" >&2

if cmp -s "$tmp/output.json" "$output"; then
  echo "google: unchanged" >&2
elif [[ "${CHECK_MODE:-0}" == 1 ]]; then
  echo "google: stale ($output)" >&2
  exit 1
else
  mv "$tmp/output.json" "$output"
  echo "google: updated $output" >&2
fi
