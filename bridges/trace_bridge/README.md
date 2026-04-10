# Citadel Trace Bridge

Status: Wave 1 workspace skeleton.

## Owns

- trace publication adapter placement
- backend-facing span and event shaping
- observability export bridge seams

## Dependencies

- `core/citadel_runtime`
- `core/observability_contract`

## Wave 1 Posture

Wave 1 only freezes the package boundary so future trace export work stays decoupled from runtime ownership and from product-surface concerns.
