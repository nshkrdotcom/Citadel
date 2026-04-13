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

/home/home/p/g/n/citadel/dev/docker/toxiproxy/verify.sh

"${MIX_CMD[@]}" test test/citadel_domain_surface_fault_injection_and_operability_test.exs
