# Citadel Core

Status: Wave 1 workspace skeleton.

## Owns

- pure values, compilers, reducers, and projectors
- scope, service-admission, session-binding, and boundary-intent logic
- deterministic wrappers that must remain runtime-owner-free

## Dependencies

- `core/contract_core`
- `core/authority_contract`
- `core/observability_contract`
- `core/policy_packs`
- explicit Wave 2 placeholder for `:jido_integration_v2_contracts`

## Wave 1 Posture

The package boundary and dependency posture are in place, but the kernel logic is intentionally not implemented yet. Wave 2 freezes the shared seam strategy; Waves 3 and 4 fill in the actual pure-core behavior.
