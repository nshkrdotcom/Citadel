# Citadel Policy Packs

Status: Wave 3 policy-pack values and selection are frozen.

## Owns

- explicit `PolicyPack`, `Selector`, `Profiles`, `RejectionPolicy`, and `Selection` values
- deterministic profile selection precedence
- pure policy inputs for rejection retryability and publication classification
- policy epoch inputs consumed by the kernel context builder

## Dependencies

- `core/contract_core`

## Posture

`core/policy_packs` is values and pure selection logic only. It does not own runtime
policy cache mutation, epoch publication, or any bridge behavior.

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
