# Citadel Policy Packs

Status: Wave 3 policy-pack values and selection are frozen.

## Owns

- explicit `PolicyPack`, `Selector`, `Profiles`, `RejectionPolicy`, and `Selection` values
- explicit `ExecutionPolicy` posture for governed lower execution
- deterministic profile selection precedence
- pure policy inputs for rejection retryability and publication classification
- policy epoch inputs consumed by the kernel context builder
- the standard coding-ops policy pack used by Mezzanine-origin coding runs

## Dependencies

- `core/contract_core`

## Posture

`core/policy_packs` is values and pure selection logic only. It does not own runtime
policy cache mutation, epoch publication, or any bridge behavior.

The standard coding-ops pack declares policy-owned execution constraints:
minimum `strict` sandbox, maximum `restricted` egress, `manual` approval
posture, bounded allowed tools and operations, read-write workspace mutation,
repo/test/source-publish command classes, and `host_local` or
`remote_workspace` placement. Runtime callers may request a subset of this
posture, but lower execution cannot widen it without a new policy decision.

## Hardening

Wave 10 adversarial hardening is package-local and runnable through normal Mix flows:

```bash
mix hardening.adversarial
mix hardening.mutation
mix hardening
```

- `mix hardening.adversarial` runs the hostile selection-input property suite in `test/citadel/policy_packs_adversarial_test.exs`
- `mix hardening.mutation` runs build-failing mutation checks over `lib/citadel/policy_packs.ex`
- `mix hardening` runs both gates
