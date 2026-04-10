<p align="center">
  <img src="assets/citadel.svg" alt="Citadel" width="220" />
</p>

<p align="center">
  <a href="https://hex.pm/packages/citadel">
    <img src="https://img.shields.io/hexpm/v/citadel.svg" alt="Hex version" />
  </a>
  <a href="https://hexdocs.pm/citadel">
    <img src="https://img.shields.io/badge/hexdocs-citadel-blue.svg" alt="HexDocs" />
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT License" />
  </a>
  <a href="https://github.com/nshkrdotcom/citadel">
    <img src="https://img.shields.io/badge/github-nshkrdotcom%2Fcitadel-black.svg" alt="GitHub" />
  </a>
</p>

# Citadel

Citadel is the Brain kernel of a generic agentic OS.

It is the host-local system that turns incoming requests into explicit Brain context, policy direction, plans, topology intent, and shared control-plane packets while preserving local continuity across async execution.

Citadel is not "agents first." It uses Jido internally where that improves typed transforms and runtime messaging, but the architecture is values-first, functions-first, and contract-first.

## Status

This repository is still in an early bootstrap stage.

The target architecture is a non-umbrella workspace. The current codebase has not yet fully converged on that shape, so the source-of-truth design currently lives in the packet at:

- `/home/home/p/g/n/jido_brainstorm/nshkrdotcom/docs/20260409/citadel_ground_up_design_docset`

## Layering

Citadel sits above the durable Spine and above the lower execution plane:

```text
Host surfaces / shells
  -> Citadel
      -> jido_integration
          -> execution plane
              -> providers, runtimes, connectors, services
```

### Citadel owns

- canonical Brain `KernelContext`
- objective formation and plan compilation
- topology intent compilation
- Brain authority compilation
- scope and target resolution
- session directory and project binding
- extension admission and service visibility
- host-local boundary intent and boundary lease expectations
- host-local session state, outbox, and signal cursor continuity
- projection into shared authority, invocation, review, and derived-state contracts

### Citadel does not own

- durable run, attempt, route, attach, review, approval, or artifact truth
- raw credential lifecycle
- sandbox implementations
- provider runtimes or lower transport mechanics
- direct connector execution
- product-shell UI state

## Kernel Waist

Citadel keeps the real Brain-side kernel seams that mattered in `jido_os`, but rebuilds them cleanly:

- local policy peek and invalidation
- scope and target resolution
- session directory and project binding
- extension admission and service visibility
- boundary lifecycle expectations

It does not preserve the old process-heavy feature sprawl.

## Jido Posture

Citadel uses Jido selectively:

- plain values and pure functions first
- `Jido.Action` for typed deterministic transforms where that helps
- `Jido.Signal` for typed ingress and lifecycle messages
- OTP owners only for unavoidable mutable coordination

Long-lived agents are not the default architecture.

## Shared Contract Posture

Citadel authors Brain policy direction, but it must do so in a stable shared shape.

The Brain authority packet must carry:

- `contract_version`
- `decision_id`
- `tenant_id`
- `request_id`
- `policy_version`
- `boundary_class`
- `trust_profile`
- `approval_profile`
- `egress_profile`
- `workspace_profile`
- `resource_profile`
- `decision_hash`
- `extensions`

Citadel-only extras belong under `extensions`. Durable review and governance lineage remain aligned to `jido_integration` shared contracts such as `SubjectRef`, `EvidenceRef`, `GovernanceRef`, `ReviewProjection`, and `DerivedStateAttachment`.

## Target Workspace Shape

The target workspace shape is:

```text
citadel/
  core/
    contract_core/
    authority_contract/
    observability_contract/
    policy_packs/
    citadel_core/
    citadel_runtime/
    conformance/
  bridges/
    invocation_bridge/
    query_bridge/
    signal_bridge/
    boundary_bridge/
    projection_bridge/
    trace_bridge/
    memory_bridge/
  apps/
    coding_assist/
    operator_assist/
```

For convenience there may eventually be one welded public artifact, but publication remains derivative of the workspace architecture rather than the other way around.

In this context:

- `Blitz` is applicable as root-only workspace tooling for compile, test, docs, and CI orchestration.
- `Weld` is the intended graph-native publication system for projecting the public `citadel` artifact from the workspace.

## Delivery Order

The near-term build order is:

1. workspace bootstrap and packet alignment
2. Brain contract freeze and shared seam alignment
3. kernel-waist values and policy packs
4. functional core and selective Jido action layer
5. runtime coordination and local kernel services
6. bridges and trace contract
7. apps and conformance
8. trace hardening and publication finalization

AITrace hardening and weld/publication are intentionally late. The kernel and contract freeze matter first.
