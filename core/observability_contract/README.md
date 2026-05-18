# Citadel Observability Contract

Status: Phase 4 audit and observability contract owner.

## Owns

- Citadel trace vocabulary ownership
- low-cardinality telemetry naming ownership
- backend-neutral observability conventions
- `Platform.AuditHashChain.v1` immutable audit-chain evidence ownership
- `Platform.ObservabilityCardinalityBounds.v1` metric, trace, audit, and
  incident export cardinality bounds ownership
- `Platform.OperationalSignal.v1` operator-facing health, latency, lag,
  cache, lease, lower invocation, receipt reduction, and live provider effect
  status signals
- `Platform.OperationalSLOThreshold.v1` thresholds and runbook refs for
  revocation bounds, tenant bypass attempts, trace/export drops, external
  secret resolver failures, stale binding cache reads, projection lag, and
  lower provider error rates

## Dependencies

- `core/contract_core`

## Phase 4 Posture

The package owns operator- and release-facing observability contracts without
coupling them to a backend. Audit evidence is append-only, hash-linked, scoped
to tenant/installation/resource/authority/idempotency/trace/release refs, and
must fail closed if actor or hash-chain continuity evidence is missing.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.

## Operational Observability

Operational signals are for operator health views and alerting. They are not
AITrace audit or replay events. `Citadel.ObservabilityContract.OperationalSignal`
owns the DTO, `OperatorSignalAdapter` shapes backend envelopes for telemetry,
metrics, logs, and traces, `OperationalSLO` owns thresholds, and
`OperationalRunbook` owns runbook entries.

See `docs/runbooks/operational_observability.md` for symptoms, commands,
expected evidence, and escalation routes.
