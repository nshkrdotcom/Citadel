# Citadel Projection Bridge

Status: Wave 5 contract frozen, published through the Wave 8 welded artifact boundary.

## Owns

- review and derived-state publication adapter placement
- shared projection seam ownership
- packet-to-review translation boundaries

## Dependencies

- `core/citadel_core`
- `core/citadel_runtime`
- `core/authority_contract`
- `core/observability_contract`
- `core/jido_integration_v2_contracts`

## Current Posture

The bridge is the explicit northbound publication boundary for
`ReviewProjection` and `DerivedStateAttachment`.

- publication stays separate from invocation submission
- replay-safe publication remains keyed by `ActionOutboxEntry.entry_id`
- the welded public artifact includes this bridge without pulling proof apps or
  `core/conformance` into the runtime package
