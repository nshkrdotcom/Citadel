# Citadel Host Surface Harness

Status: Wave 7 host-surface proof harness.

## Owns

- host/kernel seam proof harness composition
- baseline direct `IntentEnvelope` construction entrypoints
- optional structured-ingress resolver seam above Citadel
- multi-session and multi-ingress proof composition
- explicit host-facing strict dead-letter maintenance wrappers

## Dependencies

- `core/citadel_core`
- `core/policy_packs`
- `core/citadel_runtime`
- `bridges/projection_bridge`
- `bridges/signal_bridge`
- `bridges/boundary_bridge`
- `bridges/trace_bridge`

## Wave 7 Posture

The baseline path constructs `IntentEnvelope` directly and does not require any
resolver dependency. The harness may additionally exercise an optional resolver
seam, but structured ingress, synchronous rejection return, rejection
publication routing, session maintenance, and dead-letter recovery all remain
thin host-surface composition above Citadel rather than a second core.
