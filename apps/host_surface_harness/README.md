# Citadel Host Surface Harness

Status: Wave 1 workspace skeleton.

## Owns

- host/kernel seam proof harness composition
- baseline direct `IntentEnvelope` construction entrypoints
- multi-session and host-surface probe placement

## Dependencies

- `core/citadel_core`
- `core/citadel_runtime`
- `bridges/signal_bridge`
- `bridges/boundary_bridge`
- `bridges/trace_bridge`

## Wave 1 Posture

Wave 1 keeps the harness as a thin proof shell so host-surface concerns can be exercised above Citadel without dragging those seams into the core packages.
