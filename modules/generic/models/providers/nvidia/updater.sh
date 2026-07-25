#!/usr/bin/env bash
set -euo pipefail

provider_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output="$provider_dir/models.json"
models_url="https://integrate.api.nvidia.com/v1/models"
readonly model_prefixes='["z-ai/", "minimaxai/", "nvidia/nemotron"]'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [[ -n "${NVIDIA_MODELS_FILE:-}" ]]; then
  cp "$NVIDIA_MODELS_FILE" "$tmp/models.json"
else
  : "${NVIDIA_API_KEY:?NVIDIA_API_KEY is required}"
  curl --fail-with-body --retry 3 --silent --show-error \
    -H "Authorization: Bearer $NVIDIA_API_KEY" \
    "$models_url" >"$tmp/models.json"
fi

jq -Se --argjson model_prefixes "$model_prefixes" '
  if (.data | type) != "array" then
    error("NVIDIA NIM /models response has no data array")
  else
    [.data[].id as $id
      | select(any($model_prefixes[]; . as $prefix | $id | startswith($prefix)))
      | $id]
    | unique
    | map({ key: ., value: {} })
    | from_entries
  end
' "$tmp/models.json" >"$tmp/output.json"

count="$(jq 'length' "$tmp/output.json")"
echo "nvidia-nim: $count models" >&2

if cmp -s "$tmp/output.json" "$output"; then
  echo "nvidia-nim: unchanged" >&2
elif [[ "${CHECK_MODE:-0}" == 1 ]]; then
  echo "nvidia-nim: stale ($output)" >&2
  exit 1
else
  mv "$tmp/output.json" "$output"
  echo "nvidia-nim: updated $output" >&2
fi
