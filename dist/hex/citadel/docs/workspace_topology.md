# Workspace Topology

Citadel is a non-umbrella Elixir monorepo with explicit package ownership.

## Core Packages

- `core/contract_core`: neutral identifiers, host-local refs, and RFC 8785 / JCS canonicalization helpers
- `core/jido_integration_v2_contracts`: workspace-carried higher-order shared lineage and durable submission contract slice
- `core/authority_contract`: Brain-authored `AuthorityDecision.v1` schema ownership
- `core/execution_governance_contract`: Brain-to-Spine `ExecutionGovernance.v1` packet ownership
- `core/observability_contract`: trace and telemetry vocabulary ownership
- `core/policy_packs`: policy pack definitions and normalization helpers
- `core/citadel_core`: pure values, compilers, reducers, and projectors
- `core/citadel_runtime`: runtime coordination, session continuity, and local ownership processes
- `core/conformance`: black-box conformance and composition coverage

## Bridge Packages

- `bridges/invocation_bridge`: invocation handoff and lower-seam alignment placeholder
- `bridges/jido_integration_bridge`: Citadel-owned Brain-to-Spine durable submission adapter
- `bridges/query_bridge`: durable-state rehydration adapters
- `bridges/signal_bridge`: signal ingress normalization adapters
- `bridges/boundary_bridge`: boundary lifecycle and metadata adapters
- `bridges/projection_bridge`: shared review and derived-state publication adapters
- `bridges/trace_bridge`: AITrace-facing trace publication adapters
- `bridges/memory_bridge`: advisory memory integration adapters

Bridge packages stay vertical. They depend on core and runtime surfaces, not on sibling bridges.

## App Packages

- `apps/coding_assist`: thin coding-focused proof app shell
- `apps/operator_assist`: thin operator workflow proof app shell
- `apps/host_surface_harness`: thin host/kernel seam proof app with baseline direct `IntentEnvelope` construction

App packages remain composition shells. They do not become second cores.

## Publication Posture

Publication remains derivative of the workspace architecture, but the default
public artifact is now explicit:

- repo-local Weld manifest: `packaging/weld/citadel.exs`
- artifact id and package name: `citadel`
- mode: package projection, not monolith
- roots: `core/citadel_runtime`
- selected bridge closure: all `bridges/*`
- excluded by default: `apps/*`, `core/conformance`, and the root tooling project

The welded artifact keeps the source workspace authoritative. It projects the
runtime-facing core packages, the in-workspace shared contract slice, and
selected bridges without collapsing ownership or turning proof packages into
runtime dependencies.
