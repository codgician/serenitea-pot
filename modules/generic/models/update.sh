#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
check=0
requested=()

for arg in "$@"; do
  if [[ "$arg" == "--check" ]]; then
    check=1
  else
    requested+=("$arg")
  fi
done

shopt -s nullglob
updaters=("$root"/providers/*/updater.sh)
((${#updaters[@]} > 0)) || {
  echo "No model updaters found" >&2
  exit 1
}

for provider in "${requested[@]}"; do
  found=0
  for updater in "${updaters[@]}"; do
    [[ "$(basename "$(dirname "$updater")")" == "$provider" ]] && found=1
  done
  ((found)) || {
    echo "Unknown provider: $provider" >&2
    exit 1
  }
done

for updater in "${updaters[@]}"; do
  provider="$(basename "$(dirname "$updater")")"
  if ((${#requested[@]} > 0)); then
    selected=0
    for candidate in "${requested[@]}"; do
      [[ "$candidate" == "$provider" ]] && selected=1
    done
    ((selected)) || continue
  fi

  CHECK_MODE="$check" bash "$updater"
done
