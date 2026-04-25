# Citadel Execution Governance Contract

Status: Wave 10 data-layer implementation.

## Owns

- Citadel-owned `ExecutionGovernance.v1` packet ownership
- required field inventory and versioning rule for the brain-authored
  execution-governance handoff
- required `sandbox.acceptable_attestation` inventory for target-attestation
  classes that downstream Execution Plane admission may consider
- the `extensions["citadel"]` posture for Citadel-only extras
- contract-facing fixtures and validation boundary placement

## Dependencies

- `core/contract_core`

## Wave 10 Posture

`ExecutionGovernance.v1` is owned here so the packet can stay:

- pure
- versioned
- fixture-backed
- independent from `citadel_governance` compiler and projector logic

The sandbox field carries policy posture and acceptable target-attestation
classes. It does not claim that Citadel hosts a sandbox or lower execution
runtime.
