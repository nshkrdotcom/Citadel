# Citadel Core

Status: Wave 2 seam freeze.

## Owns

- pure values, compilers, reducers, and projectors
- scope, service-admission, session-binding, and boundary-intent logic
- deterministic wrappers that must remain runtime-owner-free
- `Citadel.DecisionHash`
- the Citadel-owned `InvocationRequest`, `BoundaryIntent`, and `TopologyIntent` seam

## Dependencies

- `core/contract_core`
- `core/jido_integration_v2_contracts`
- `core/authority_contract`
- `core/observability_contract`
- `core/policy_packs`

## Wave 2 Posture

Wave 2 freezes the public carrier shapes before deeper runtime behavior:

- `Citadel.DecisionHash` computes `decision_hash` from normalized shared
  `AuthorityDecision.v1` packets through `core/contract_core`
- `Citadel.InvocationRequest` is a Citadel seam, not an import of the current
  downstream `Jido.Integration.V2.InvocationRequest`
- `InvocationRequest.authority_packet` is explicitly the shared
  `AuthorityDecision.v1` packet
- structured ingress stays explicit through provenance refs or hashes; raw NL
  is not the kernel contract
- Waves 3 and 4 may tighten ingress mappings, but incompatible carrier-shape
  changes now require an explicit `schema_version` step

## Hardening

Wave 10 adversarial hardening is package-local and runnable through normal Mix flows:

```bash
mix hardening.adversarial
mix hardening.mutation
mix hardening
```

- `mix hardening.adversarial` runs the hostile-input property suite in `test/citadel/pure_core_adversarial_test.exs`
- `mix hardening.mutation` runs build-failing mutation checks over `intent_envelope`, `decision_values`, `kernel_values`, and `runtime_values`
- `mix hardening` runs both gates
