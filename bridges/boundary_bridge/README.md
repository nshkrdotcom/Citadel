# Citadel Boundary Bridge

Status: Wave 1 workspace skeleton.

## Owns

- boundary lifecycle adapter placement
- lease and boundary metadata translation seams
- host-boundary event shaping boundaries

## Dependencies

- `core/citadel_core`
- `core/citadel_runtime`
- `core/authority_contract`

## Wave 1 Posture

Wave 1 only fixes the ownership seam so boundary lifecycle work lands in one place instead of leaking across host surfaces or runtime internals.
