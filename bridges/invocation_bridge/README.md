# Citadel Invocation Bridge

Status: Wave 2 seam freeze.

## Owns

- invocation handoff adapter placement
- lower-seam request shaping boundaries
- provider-facing packet projection seams
- explicit supported `InvocationRequest.schema_version` entrypoint handling

## Dependencies

- `core/citadel_core`
- `core/citadel_runtime`
- `core/authority_contract`
- `core/observability_contract`
- explicit Wave 2 placeholder for `:jido_integration_v2_contracts`

## Wave 2 Posture

The bridge now freezes its entry posture:

- it consumes the Citadel-owned `Citadel.InvocationRequest` seam
- it treats `authority_packet` as the shared `AuthorityDecision.v1` packet
- it exposes the supported `schema_version` set explicitly and rejects
  unsupported versions before lower projection begins
- it still does not assume the lower execution-envelope family already exists
  downstream
