# Citadel Invocation Bridge

Status: Wave 1 workspace skeleton.

## Owns

- invocation handoff adapter placement
- lower-seam request shaping boundaries
- provider-facing packet projection seams

## Dependencies

- `core/citadel_core`
- `core/citadel_runtime`
- `core/authority_contract`
- `core/observability_contract`
- explicit Wave 2 placeholder for `:jido_integration_v2_contracts`

## Wave 1 Posture

Wave 1 establishes the package boundary and dependency posture only. The real lower-seam invocation adapter logic lands after the shared execution contracts are frozen.
