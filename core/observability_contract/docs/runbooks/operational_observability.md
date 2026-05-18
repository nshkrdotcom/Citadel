# Operational Observability Runbook

Operational observability is the operator health path. It is separate from
AITrace audit/replay proof events. Backend envelopes may carry low-cardinality
metric labels, redacted log fields, and trace refs; they must not carry raw
provider payloads or raw secrets.

## binding_lookup

Symptom: binding lookup health is degraded, stale, or outside the expected cache
bound.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`

Expected evidence:

- binding lookup signal
- active binding cache age
- fail-closed stale action

Escalation: `mezzanine-config-registry-triage`.

## authority_decision

Symptom: authority decision health is degraded or rejecting expected governed
operations.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`

Expected evidence:

- authority decision signal
- tenant-scoped decision metadata
- safe action

Escalation: `citadel-runtime-triage`.

## credential_lease_materialization

Symptom: credential lease materialization is degraded at the resolver or lease
boundary.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`

Expected evidence:

- credential lease signal
- redacted credential handle ref
- no raw secret fields

Escalation: `jido-auth-triage`.

## lower_invocation

Symptom: lower invocation health is degraded or returning provider errors.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`
- `~/scripts/with_bash_secrets mix extravaganza.headless.live.smoke`

Expected evidence:

- lower invocation signal
- binding descriptor dispatch evidence
- receipt status

Escalation: `mezzanine-integration-triage`.

## receipt_reduction

Symptom: receipt reduction is degraded or unable to derive operator disposition.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`

Expected evidence:

- receipt reduction signal
- lineage-derived disposition
- no raw result payload

Escalation: `mezzanine-evidence-triage`.

## projection_lag

Symptom: operator projections are lagging or reporting stale visible state.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`

Expected evidence:

- projection lag signal
- queue depth
- operator stale-projection status

Escalation: `app-kit-projection-triage`.

## aitrace_export_lag

Symptom: AITrace export lag is visible to operators without using AITrace as
health transport.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`
- `MIX_ENV=test mix test --only tenant_replay`

Expected evidence:

- AITrace export lag signal
- drop counter stays zero
- AITrace replay tests pass

Escalation: `aitrace-runtime-triage`.

## revocation_bound_ms

Symptom: authority revocation visibility is outside the configured bound.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`

Expected evidence:

- `citadel.operational.authority.revocation_bound_ms`
- authority rejection evidence

Escalation: `citadel-runtime-triage`.

## tenant_bypass_attempts

Symptom: a cross-tenant authority or credential path attempted to bypass tenant
scope.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`

Expected evidence:

- tenant bypass metric is zero
- P0 authority rejection log without raw payload

Escalation: `citadel-security-page`.

## trace_export_drops

Symptom: trace export lag or drop counters indicate operator evidence may be
incomplete.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`
- `MIX_ENV=test mix test --only tenant_replay`

Expected evidence:

- AITrace export lag signal
- drop counter stays zero
- AITrace replay tests pass

Escalation: `aitrace-runtime-triage`.

## external_secret_resolver_failures

Symptom: credential lease materialization failed at the external resolver
boundary.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`

Expected evidence:

- credential lease signal
- redacted credential handle ref
- no raw secret fields

Escalation: `jido-auth-triage`.

## binding_cache_stale_reads

Symptom: binding cache served or attempted to serve a stale epoch.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`

Expected evidence:

- binding lookup cache age
- stale read counter is zero
- fail-closed action

Escalation: `mezzanine-config-registry-triage`.

## projection_lag_ms

Symptom: operator projections are stale beyond the configured lag threshold.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`

Expected evidence:

- projection lag metric
- operator stale-projection status

Escalation: `app-kit-projection-triage`.

## lower_provider_error_rate

Symptom: lower provider effects are returning errors above the platform
threshold.

Commands:

- `mix test test/citadel/observability_contract/operational_signal_test.exs`
- `~/scripts/with_bash_secrets mix extravaganza.headless.live.smoke`

Expected evidence:

- lower invocation signal
- live provider effect status
- receipt reduction status

Escalation: `mezzanine-integration-triage`.

## live_provider_effect_status

Symptom: live provider effect status is unhealthy for a product command.

Commands:

- `~/scripts/with_bash_secrets mix extravaganza.headless.live.smoke`

Expected evidence:

- live provider effect status
- operator-visible health without AITrace replay

Escalation: `extravaganza-operator-triage`.
