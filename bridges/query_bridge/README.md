# Citadel Query Bridge

Status: Wave 1 workspace skeleton.

## Owns

- durable-state rehydration adapter placement
- external snapshot lookup boundaries
- query normalization seams above Citadel core

## Dependencies

- `core/citadel_governance`
- `core/citadel_kernel`

## Wave 1 Posture

Wave 1 only materializes the bridge boundary so later query and rehydration work stays out of runtime internals and does not leak into sibling bridges.
