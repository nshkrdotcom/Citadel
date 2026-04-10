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
