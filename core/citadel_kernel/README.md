# Citadel Kernel

Status: Wave 1 workspace skeleton.

## Owns

- session runtime ownership
- signal ingress, outbox replay, and boundary lease tracking ownership
- local catalogs, caches, and runtime coordination placement

## Dependencies

- `core/citadel_governance`
- `core/authority_contract`
- `core/observability_contract`

## Wave 1 Posture

Wave 1 creates the runtime package and its supervision entrypoint only. All real coordination logic is deferred until the runtime wave so the workspace shape comes first.
