# Shared Contract Dependency Strategy

Citadel carries the higher-order `Jido.Integration.V2` shared contract slice as
a workspace package at `core/jido_integration_contracts`.

## Packages Using The Shared Contract Slice

The public Citadel packages that rely on these shared modules resolve them
through the in-workspace package:

- `core/citadel_governance`
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
  the shared schema helper module from the `jido_integration_contracts`
  package

## Publication Rule

The welded `citadel` artifact includes `core/jido_integration_contracts` as
an internal package instead of emitting `:jido_integration_contracts` as an
external Hex, git, or path dependency.

That keeps the projected package self-contained and Hex-buildable while
preserving the shared public module names and package ownership boundaries.

The Phase 5 version-skew disposition for this package is
`welded_internal_slice_with_upstream_equivalence_proof`. The executable proof is
`test/citadel/jido_contract_home_verification_test.exs`, which compares every
vendored `Jido.Integration.V2` source file under
`core/jido_integration_contracts/lib` to the canonical upstream sibling at
`../jido_integration/core/contracts/lib`. The local slice may carry only files
present upstream, and the file contents must match byte-for-byte.

## Legacy Generated Artifact Disposition

The former `core/jido_integration_v2_contracts` and
`:jido_integration_v2_contracts` names are retired. They must not appear in
tracked source paths, the current `dist/hex/citadel` projection, or the current
`dist/release_bundles/citadel` release bundle.

Any remaining `jido_integration_v2_contracts` path under ignored
`/dist/archive/` output is non-publishable generated history only. It is not a
dependency source, not a current projection input, and not release evidence.
`test/citadel/jido_contract_legacy_artifact_scan_test.exs` is the guard for
this disposition.

## Consumer Dependency Proof

Workspace consumers that directly compile against the shared contracts use the
welded local slice at `core/jido_integration_contracts` through package-local
path dependencies. The allowed direct consumers are
`core/citadel_governance`, `core/conformance`, `bridges/invocation_bridge`,
`bridges/jido_integration_bridge`, and `bridges/projection_bridge`.

Root workspace dependency resolution remains centralized in
`Citadel.Build.DependencyResolver`, which can resolve the canonical upstream
`jido_integration/core/contracts` sibling checkout or the published Hex
projection. The direct `citadel_domain_surface` package is not part of the
default welded Citadel artifact; when its lock references the shared contracts,
it pins the upstream Git repository with sparse `core/contracts` checkout
instead of the Citadel-local slice.

`test/citadel/jido_contract_consumer_dependency_test.exs` enforces those
consumer modes and rejects independent local forks.

## Runtime Rule

The vendored package is still a runtime boundary, not a license to mix
authoritative upstream structs freely into Citadel internals.

Citadel-owned bridge code must reconstruct shared lineage packets through
`Citadel.JidoIntegrationBridge.LineageCodec` before local bridge consumers
touch them.
