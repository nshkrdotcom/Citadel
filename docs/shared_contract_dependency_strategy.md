# Shared Contract Dependency Strategy

Wave 2 freezes which shared seams are consumed directly and which remain
Citadel-owned until later waves.

## Packages Carrying The Shared Contract Dependency

The packages that consume already-existing higher-order shared contracts declare
the dependency explicitly in their `mix.exs` files:

- `core/citadel_core`
- `bridges/invocation_bridge`
- `bridges/projection_bridge`
- `core/conformance`

## Resolution Order

`build_support/dependency_resolver.exs` resolves `:jido_integration_v2_contracts` in this order:

1. `CITADEL_JIDO_INTEGRATION_CONTRACTS_PATH`
2. `JIDO_INTEGRATION_PATH/core/contracts`
3. `/home/home/p/g/n/jido_integration/core/contracts`
4. published placeholder requirement `~> 0.1.0`

That keeps local cross-repo iteration easy while preserving the published
fallback requirement `~> 0.1.0` for release-facing compatibility verification.

## Wave 2 Boundary

Wave 2 freezes:

- `core/citadel_core` consumes higher-order lineage shapes such as
  `SubjectRef`, `EvidenceRef`, `GovernanceRef`, `ReviewProjection`, and
  `DerivedStateAttachment`
- `core/authority_contract` keeps `AuthorityDecision.v1` local to Citadel while
  matching the Brain baseline
- `core/citadel_core` keeps `InvocationRequest`, `BoundaryIntent`, and
  `TopologyIntent` local to Citadel until the later lower-envelope freeze
- `bridges/invocation_bridge` consumes that Citadel-owned `InvocationRequest`
  seam explicitly instead of assuming downstream `Jido.Integration.V2.InvocationRequest`
  equivalence

No Wave 2 package may assume the lower execution packet family already exists
downstream as concrete modules.
