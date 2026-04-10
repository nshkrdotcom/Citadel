# Citadel Authority Contract

Status: Wave 2 seam freeze.

## Owns

- Brain-authored `AuthorityDecision.v1` packet ownership
- required field inventory and versioning rule for the Brain authority baseline
- the `extensions["citadel"]` posture for Citadel-only extras
- contract-facing fixtures and validation boundary placement

## Dependencies

- `core/contract_core`

## Wave 2 Posture

`AuthorityDecision.v1` is now frozen here against the Brain baseline:

- required shared fields stay first-class
- incompatible field or semantic changes require an explicit successor packet
- Citadel-only extras stay under `extensions["citadel"]`
- fixture-backed drift checks fail immediately on unauthorized mutation
