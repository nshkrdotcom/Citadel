# Citadel Operator Assist

Status: Wave 1 workspace skeleton.

## Owns

- operator-focused proof app composition
- review and approval workflow shell wiring
- app-surface entrypoints above Citadel runtime coordination

## Dependencies

- `core/citadel_governance`
- `core/citadel_kernel`
- `bridges/invocation_bridge`
- `bridges/query_bridge`
- `bridges/signal_bridge`
- `bridges/boundary_bridge`
- `bridges/projection_bridge`
- `bridges/trace_bridge`

## Wave 1 Posture

Wave 1 keeps this package intentionally shallow. It pins the operator app seam so approval and supervision flows can be added later without collapsing back into the kernel packages.
