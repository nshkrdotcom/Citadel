# Citadel Memory Bridge

Status: Wave 1 workspace skeleton.

## Owns

- advisory memory adapter placement
- memory-side normalization seams
- correlation-envelope translation for memory exchanges

## Dependencies

- `core/citadel_core`
- `core/citadel_runtime`

## Wave 1 Posture

Wave 1 keeps advisory memory integration at a distinct bridge seam so later connector work does not distort core kernel or runtime ownership.
