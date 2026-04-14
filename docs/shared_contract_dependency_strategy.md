# Shared Contract Dependency Strategy

Citadel carries the higher-order `Jido.Integration.V2` shared contract slice as
a workspace package at `core/jido_integration_v2_contracts`.

## Packages Using The Shared Contract Slice

The public Citadel packages that rely on these shared modules resolve them
through the in-workspace package:

- `core/citadel_core`
- `bridges/invocation_bridge`
- `bridges/jido_integration_bridge`
- `bridges/projection_bridge`
- `core/conformance`

## Included Modules

The workspace package currently carries the shared modules Citadel publishes
across its runtime-facing seams:

- lineage packets:
  `Jido.Integration.V2.SubjectRef`,
  `Jido.Integration.V2.EvidenceRef`,
  `Jido.Integration.V2.GovernanceRef`,
  `Jido.Integration.V2.ReviewProjection`,
  `Jido.Integration.V2.DerivedStateAttachment`
- durable submission packets:
  `Jido.Integration.V2.CanonicalJson`,
  `Jido.Integration.V2.SubmissionIdentity`,
  `Jido.Integration.V2.AuthorityAuditEnvelope`,
  `Jido.Integration.V2.ExecutionGovernanceProjection`,
  `Jido.Integration.V2.SubmissionAcceptance`,
  `Jido.Integration.V2.SubmissionRejection`,
  `Jido.Integration.V2.BrainInvocation`
- copied upstream validation helpers:
  `Jido.Integration.V2.Contracts`,
  the shared schema helper module from the `jido_integration_v2_contracts`
  package

## Publication Rule

The welded `citadel` artifact includes `core/jido_integration_v2_contracts` as
an internal package instead of emitting `:jido_integration_v2_contracts` as an
external Hex, git, or path dependency.

That keeps the projected package self-contained and Hex-buildable while
preserving the shared public module names and package ownership boundaries.

## Runtime Rule

The vendored package is still a runtime boundary, not a license to mix
authoritative upstream structs freely into Citadel internals.

Citadel-owned bridge code must reconstruct shared lineage packets through
`Citadel.JidoIntegrationBridge.LineageCodec` before local bridge consumers
touch them.
