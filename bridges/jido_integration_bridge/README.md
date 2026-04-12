# Citadel Jido Integration Bridge

Status: durable submission bridge slice.

## Owns

- Citadel-owned `ExecutionIntentEnvelope.V2 -> Jido.Integration.V2.BrainInvocation`
  projection
- the single mandatory shared-lineage coercion choke point for Citadel-local
  vendored `Jido.Integration.V2` structs
- the configurable downstream transport seam used by
  `Citadel.InvocationBridge`

## Dependencies

- `core/citadel_core`
- `core/authority_contract`
- `core/execution_governance_contract`
- `bridges/invocation_bridge`
- `core/jido_integration_v2_contracts`

## Posture

- bridge ownership stays in `citadel`
- the runtime-facing shared packet family stays `Jido.Integration.V2`
- transport is pluggable; packet projection and lineage coercion stay pure
