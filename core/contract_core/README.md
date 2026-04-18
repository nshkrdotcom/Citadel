# Citadel Contract Core

Status: Wave 2 seam freeze.

## Owns

- neutral identifiers and low-level host-local refs
- packet attribute normalization helpers
- RFC 8785 / JCS canonicalization surface for shared packet hashing
- explicit normalization failure for unsupported non-JSON values and duplicate post-normalization keys

## Dependencies

- `{:jcs, "~> 0.2.0"}`

## Wave 2 Posture

`Citadel.DecisionHash` stays in `core/citadel_governance`, but all canonical JSON
normalization and `Jcs.encode/1` ownership flows through this package. Shared
packet hashing must not bypass this helper surface with ad hoc `Jason.encode!/1`
or implicit struct enumeration.
