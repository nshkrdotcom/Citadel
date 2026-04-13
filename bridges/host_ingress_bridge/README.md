# Citadel Host Ingress Bridge

Status: canonical public structured host-ingress surface.

## Owns

- the projected public host-ingress seam above Citadel
- typed request-context normalization for structured host submissions
- pure compilation from `IntentEnvelope` into `InvocationRequest.V2`
- canonical `submit_invocation` outbox payload encoding and decoding
- durable ingress persistence through `SessionServer` / `SessionDirectory`

## Dependencies

- `core/citadel_core`
- `core/citadel_runtime`
- `core/authority_contract`
- `core/execution_governance_contract`
- `core/policy_packs`

## Posture

This package is the downstream-consumer host-ingress boundary. It is the
projected public surface higher repos may depend on.

It is not a proof-only harness. Proof packages may wrap it, but they must not
replace it.
