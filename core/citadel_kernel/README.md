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

## Runtime Coordination Guides

- [`docs/signal_ingress_characterization.md`](docs/signal_ingress_characterization.md)
  records the SignalIngress behavior contract and extraction boundaries used by
  the code smell remediation phases.

## Wave 1 Posture

Wave 1 creates the runtime package and its supervision entrypoint only. All real coordination logic is deferred until the runtime wave so the workspace shape comes first.
