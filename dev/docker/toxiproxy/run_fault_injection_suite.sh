#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

if [[ -f "${HOME}/.asdf/asdf.sh" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.asdf/asdf.sh"
fi

if command -v asdf >/dev/null 2>&1; then
  MIX_CMD=(asdf exec mix)
else
  MIX_CMD=(mix)
fi

export CITADEL_REQUIRE_TOXIPROXY=1

dev/docker/toxiproxy/verify.sh

run_suite() {
  local workdir="$1"
  local test_file="$2"

  (
    cd "$workdir"
    "${MIX_CMD[@]}" test "$test_file"
  )
}

run_suite "bridges/invocation_bridge" "test/citadel/infrastructure_fault_injection_test.exs"
run_suite "bridges/projection_bridge" "test/citadel/infrastructure_fault_injection_test.exs"
run_suite "core/citadel_kernel" "test/citadel/kernel/infrastructure_fault_injection_test.exs"
