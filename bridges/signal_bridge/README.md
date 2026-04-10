# Citadel Signal Bridge

Status: Wave 1 workspace skeleton.

## Owns

- signal ingress normalization adapters
- channel-to-kernel signal translation placement
- ingress metadata shaping seams

## Dependencies

- `core/citadel_runtime`
- `core/observability_contract`

## Wave 1 Posture

Wave 1 keeps signal normalization in its own vertical package so host-surface adapters can evolve without pushing ingress semantics into the runtime core.
