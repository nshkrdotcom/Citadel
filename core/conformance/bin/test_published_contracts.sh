#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

run_mix() {
  if command -v asdf >/dev/null 2>&1; then
    asdf exec mix "$@"
  else
    mix "$@"
  fi
}

run_contract_tests() {
  local mode="$1"
  shift

  if command -v asdf >/dev/null 2>&1; then
    asdf exec elixir --erl "-citadel_conformance contract_mode ${mode}" -S mix test "$@"
  else
    elixir --erl "-citadel_conformance contract_mode ${mode}" -S mix test "$@"
  fi
}

cd "${PROJECT_ROOT}"

# Dependency sources are selected by Mix deps and the repository dependency-source
# manifest. This script only switches conformance behavior through explicit VM
# application config.

if run_mix deps.get >/tmp/citadel_conformance_published_gate.log 2>&1; then
  run_contract_tests published_artifact "$@"
  exit $?
fi

echo "Published dependency resolution failed; falling back to staged contract mode." >&2

run_mix deps.get
run_contract_tests staged_artifact "$@"
