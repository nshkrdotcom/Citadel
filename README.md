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

Citadel is the command and control layer for the AI-powered enterprise.

It is a Brain-first Elixir runtime for turning host requests into typed objectives, plans, topology intent, authority decisions, Spine-facing invocation requests, and local session transitions. It is designed to keep reasoning authority and host-local cognitive state in one focused system while pushing durable execution truth and lower runtime mechanics across explicit boundaries.

The design source material for this repository currently exists as a ground-up packet written for a system named `fabric`. In this repository, that design is adopted as `Citadel`: same architecture, same boundaries, different name.

## Status

This repository is at an early scaffold stage.

Today it contains the initial Mix application skeleton. The README describes the intended architecture, delivery sequence, and contribution direction for building Citadel into the Brain repo described below.

## North Star

Citadel is the Brain-only repo in a larger system stack:

```text
Host surfaces / product shells
  -> Citadel
      -> Spine integration layer
          -> execution plane
              -> providers, processes, services, connectors, runtimes
```

Citadel owns:

- reasoning authority
- objective formation and plan compilation
- topology intent and local policy compilation
- host-local session and planning state
- pure transition generation
- projection of Brain-authored decisions into Spine-facing contracts

Citadel does not own:

- durable run, attempt, approval, publication, or artifact truth
- transport processes, sandbox backends, shell execution, or lower session mechanics
- direct connector execution
- operator-shell product state

## Design Principles

Citadel follows a strict inside-out design sequence:

1. data
2. functions
3. tests
4. boundaries
5. lifecycle
6. workers

Hard architectural rules:

- functional core first, OTP second
- reducers emit pure `SessionTransition` values
- actions are dispatched only after state commit
- session state stores opaque external refs, not a shadow durable ledger
- execution is signal-driven and query-based after submission, never an inline blocking wait
- lower runtime, auth, transport, and connector concerns stay outside the Citadel boundary

## Core Flow

The canonical request path is:

```text
Host request
  -> KernelContext build
  -> Objective compilation
  -> Plan compilation
  -> Topology intent compilation
  -> Policy compilation
  -> Authority decision
  -> Invocation projection
  -> Spine submission
  -> signal ingress / rehydration query
  -> result reduction
  -> SessionTransition
  -> post-commit local action dispatch
```

This split matters: Citadel decides, projects, reduces, and orchestrates host-local continuity. It does not become the durable system of record for remote execution.

## Architecture

### Functional Core

The Brain logic should make sense without reading GenServer code. The core module families are:

- `Citadel.ContextBuilder` and `Citadel.ScopeResolver`
- `Citadel.ObjectiveCompiler` and constraint normalization
- `Citadel.PlanCompiler`, step selection, and target hint compilation
- `Citadel.TopologyIntentCompiler`
- `Citadel.PolicyCompiler` and `Citadel.AuthorityCompiler`
- `Citadel.InvocationProjector` and review projection
- `Citadel.ResultReducer`, `Citadel.ReviewReducer`, and `Citadel.SessionReducer`

These modules operate on plain data such as:

- `KernelContext`
- `Objective`
- `Plan`
- `TopologyIntent`
- `AuthorityDecision`
- `RuntimeObservation`
- `ExternalRef`
- `LocalAction`
- `SessionTransition`
- `SessionState`

### Ports And Adapters

Citadel talks to the outside world only through small, explicit ports:

- `InvocationSink` for Spine submission
- `RuntimeQuery` for durable-state rehydration
- `SignalSource` for result, review, and lifecycle signals
- `Trace` for trace creation and span emission
- `PolicyPack` for local policy metadata
- `Memory` for advisory memory reads and writes
- `Clock` and `Id` for deterministic time and identity injection

Canonical adapters are expected to target:

- the Spine integration layer for invocation, signal, and rehydration boundaries
- AITrace-style tracing for planning and reduction spans
- policy-pack and memory services as narrow replaceable dependencies

### OTP Runtime

OTP exists to wrap the functional core, not replace it.

The intended top-level supervision tree is:

```text
Citadel.Application
  -> Citadel.Supervisor
      -> Registry
      -> DynamicSupervisor (session servers)
      -> DecisionTaskSupervisor
      -> ActionTaskSupervisor
      -> PolicyCache
      -> TopologyCache
      -> SignalIngress
      -> TracePublisher
```

Processes exist for:

- host-local mutable session state
- adapter coordination
- cache ownership
- signal ingress and subscription continuity
- supervised async decision and action work

They do not exist to give every domain noun its own process.

## Session Model

Session servers own only ephemeral host-local state.

On attach or restart, a session should:

1. ensure subscription continuity through `SignalIngress`
2. rehydrate opaque external refs and signal cursor from Spine-owned truth
3. replay retry-safe outbox entries
4. resume accepting requests

Reducers never perform side effects directly. Instead they emit a `SessionTransition` that contains the next state and any deferred `LocalAction` values. The session server commits state first, then hands pending actions to an `ActionDispatcher`.

## Repository Direction

Citadel should remain one focused Elixir repository rather than splitting too early into multiple runtime packages.

The intended shape is:

```text
citadel/
  mix.exs
  README.md
  lib/
    citadel.ex
    citadel/application.ex
    citadel/supervisor.ex
    citadel/*.ex
    citadel/ports/*.ex
    citadel/adapters/*.ex
    citadel/runtime/*.ex
  test/
  integration_test/
  docs/
```

The namespace rule is simple: use `Citadel.*` to make Brain ownership obvious.

## Testing Strategy

Confidence should be built in layers:

- data tests for struct validation and invariants
- pure function tests for compilation and reduction logic
- boundary contract tests for adapters and request/response mapping
- runtime tests for session lifecycle, signal continuity, outbox replay, and bounded concurrency
- vertical slice tests that prove one request can go through submission, result return, and reduction

High-value properties include:

- reducer idempotency under repeated result delivery
- deterministic plan and authority compilation
- stable projection of context and authority into boundary contracts
- stale-epoch and expired-authority rejection before handoff

## Delivery Plan

The recommended build sequence is:

1. shared contract alignment
2. functional core
3. boundary adapters
4. minimal OTP runtime
5. first vertical slice
6. review-aware and publication-aware flows

Management rule: if a phase pulls lower-runtime transport or execution ownership into Citadel, stop and revisit the boundary. That is usually a design bug.

## Development

Requirements:

- Elixir `~> 1.18`
- Erlang/OTP compatible with your Elixir toolchain

Common commands:

```bash
mix deps.get
mix test
mix docs
```

## Contributing

Contributions should preserve the core boundary:

- keep pure decision logic in plain modules
- add OTP only where state, concurrency, or failure isolation are real concerns
- do not mirror durable execution truth in session state
- do not add direct lower-runtime or connector ownership inside Citadel

If you introduce a boundary, define a port first and make the adapter replaceable in tests.

## License

Citadel is released under the [MIT License](LICENSE).
