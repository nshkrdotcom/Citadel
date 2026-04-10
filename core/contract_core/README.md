# Citadel Contract Core

Status: Wave 1 workspace skeleton.

## Owns

- neutral identifiers and low-level host-local refs
- correlation-envelope helper ownership
- RFC 8785 / JCS canonicalization surface for shared packet hashing

## Dependencies

- `{:jcs, "~> 0.2.0"}`

## Wave 1 Posture

This package is intentionally shallow. It establishes the package boundary and materializes the packet-pinned `:jcs` dependency without implementing deeper kernel logic ahead of the later contract waves.
