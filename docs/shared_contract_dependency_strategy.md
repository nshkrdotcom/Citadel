# Shared Contract Dependency Strategy

Citadel carries the higher-order `Jido.Integration.V2` lineage contract slice
as a workspace package at `core/jido_integration_v2_contracts`.

## Packages Using The Shared Contract Slice

The public Citadel packages that rely on these shared modules resolve them
through the in-workspace package:

- `core/citadel_core`
- `bridges/invocation_bridge`
- `bridges/projection_bridge`
- `core/conformance`

## Included Modules

The workspace package currently carries the shared modules Citadel publishes
across its runtime-facing seams:

- `Jido.Integration.V2.SubjectRef`
- `Jido.Integration.V2.EvidenceRef`
- `Jido.Integration.V2.GovernanceRef`
- `Jido.Integration.V2.ReviewProjection`
- `Jido.Integration.V2.DerivedStateAttachment`

## Publication Rule

The welded `citadel` artifact includes `core/jido_integration_v2_contracts` as
an internal package instead of emitting `:jido_integration_v2_contracts` as an
external Hex, git, or path dependency.

That keeps the projected package self-contained and Hex-buildable while
preserving the shared public module names and package ownership boundaries.
