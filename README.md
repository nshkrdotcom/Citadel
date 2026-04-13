<p align="center">
  <img src="assets/citadel.svg" alt="Citadel" width="220" />
</p>

# Citadel

Citadel is the host-local Brain kernel for a generic agentic OS. It accepts structured ingress at the kernel boundary, compiles Brain policy and planning decisions, preserves host-local session continuity, and projects Brain-authored packets toward the shared `jido_integration` contracts layer.

This repository is now aligned to the packet-defined non-umbrella workspace. The old single-package scaffold is gone; the package graph and ownership boundaries are the source of truth.

The workspace now also carries a separately publishable northbound typed surface
package:

- `surfaces/citadel_domain_surface`
- public namespace: `Citadel.DomainSurface`
- role: typed host-facing command, query, route, and capability boundary above
  the Citadel kernel

## Stack Position

```text
host surfaces / shells
  -> Citadel
      -> jido_integration
          -> execution plane
              -> providers, runtimes, services, connectors
```

Citadel owns:

- canonical Brain context construction
- structured ingress handling at `IntentEnvelope`
- objective, plan, topology, and authority compilation
- host-local session continuity and runtime coordination
- projection into shared authority, invocation, review, and derived-state seams

Citadel does not own:

- durable run, attempt, approval, review, or artifact truth
- lower execution transports or provider runtimes
- raw credential lifecycle
- raw natural-language interpretation
- product-shell UI or channel state

## Workspace

```text
citadel/
  core/
    contract_core/
    jido_integration_v2_contracts/
    authority_contract/
    execution_governance_contract/
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
    host_ingress_bridge/
    projection_bridge/
    trace_bridge/
    memory_bridge/
  apps/
    coding_assist/
    operator_assist/
    host_surface_harness/
  surfaces/
    citadel_domain_surface/
```

Package ownership is explicit:

- `core/*` owns values, contracts, policy packs, runtime coordination, and conformance.
- `bridges/*` owns adapter code only.
- `apps/*` owns thin proof-app composition shells and stays above the kernel.
- `surfaces/*` owns northbound publishable typed surfaces that sit above the
  kernel without becoming second cores.

The third proof app, `apps/host_surface_harness`, is part of the workspace from day one. It exists to prove host/kernel seams, multi-session behavior, and structured ingress above Citadel without pushing those concerns into the core.

The public structured host-ingress seam now lives in
`bridges/host_ingress_bridge`. That package owns the typed host-facing request
context, accepted-result contract, pure invocation compiler, and the public
`Citadel.HostIngress` facade that host applications call before the lower
`jido_integration` seam.

## Toolchain And Build

Citadel is pinned to Elixir `~> 1.19` and OTP 28. The repo-level `.tool-versions` file tracks the exact bootstrap pair:

- `elixir 1.19.5-otp-28`
- `erlang 28.3`

The root Mix project is a tooling-only workspace orchestrator. Wave 1 materializes the packet-pinned workspace tooling and dependency posture explicitly:

- `{:blitz, "~> 0.2.0", runtime: false}` for workspace fanout
- `{:weld, "~> 0.5.0", runtime: false}` for repo-local package projection and release preparation
- `{:jcs, "~> 0.2.0"}` in `core/contract_core` for RFC 8785 / JCS ownership

Common commands:

```bash
mix deps.get
mix monorepo.deps.get
mix monorepo.compile
mix monorepo.test
```

Static analysis and build hardening commands:

```bash
mix lint.packet_seams
mix lint.strict
mix monorepo.dialyzer
mix static.analysis
mix ci
```

Pure-core adversarial hardening commands:

```bash
mix hardening.pure_core.adversarial
mix hardening.pure_core.mutation
mix hardening.pure_core
```

- `mix hardening.pure_core.adversarial` runs the Wave 10 property suites in `core/citadel_core` and `core/policy_packs`
- `mix hardening.pure_core.mutation` runs build-failing mutation checks for the same pure-core packages
- `mix hardening.pure_core` runs both gates

The Wave 9 hardening posture is enforced in code and CI:

- `mix lint.packet_seams` fails on `String.to_atom/1` anywhere in packet-critical workspace paths and blocks raw `map()` or `keyword()` public seam specs on the tracked ingress, bridge, runtime, and trace modules.
- `mix lint.strict` runs a curated high-signal Credo config across the workspace libraries instead of style-noise checks that do not protect packet seams.
- `mix static.analysis` also runs the `citadel_domain_surface` package-local
  seam lint and strict lint so the northbound typed boundary keeps its own
  publication discipline inside the monorepo.
- `mix monorepo.dialyzer` fans out `mix dialyzer --halt-exit-status` across the real workspace graph through Blitz, so any Dialyzer warning fails the build.
- `.github/workflows/ci.yml` runs format, compile, packet seam lint, strict lint, Dialyzer, and tests as separate CI steps.

Publication is now finalized as a derivative workspace boundary. The repo-local
Weld manifest lives at `packaging/weld/citadel.exs`, projects the public
`citadel` artifact in package-projection mode, keeps `apps/*`,
`core/conformance`, and `surfaces/citadel_domain_surface` out of the default
artifact, carries the
`core/jido_integration_v2_contracts` slice in-workspace, and preserves package
ownership instead of flattening the workspace into a monolith.

Common publication commands:

```bash
mix weld.inspect packaging/weld/citadel.exs
mix weld.verify packaging/weld/citadel.exs
mix weld.release.prepare packaging/weld/citadel.exs
mix weld.release.archive packaging/weld/citadel.exs
```

## Shared Contract Strategy

Citadel now carries the higher-order `Jido.Integration.V2` lineage contract
slice as an in-workspace package at `core/jido_integration_v2_contracts`.

That package provides the shared modules the public Citadel surface publishes
today:

- `Jido.Integration.V2.SubjectRef`
- `Jido.Integration.V2.EvidenceRef`
- `Jido.Integration.V2.GovernanceRef`
- `Jido.Integration.V2.ReviewProjection`
- `Jido.Integration.V2.DerivedStateAttachment`

Keeping that slice inside the workspace lets the welded `citadel` artifact stay
self-contained and Hex-buildable while preserving the shared public module
names.

## Documentation

The packet that drives this repo lives at:

- `/home/home/p/g/n/jido_brainstorm/nshkrdotcom/docs/20260409/citadel_ground_up_design_docset`

Local workspace docs now live in:

- `README.md`
- `docs/README.md`
- `docs/workspace_topology.md`
- `docs/shared_contract_dependency_strategy.md`
- package-level `README.md` files under every `core/*`, `bridges/*`, `apps/*`,
  and `surfaces/*` package

## Fault Injection Harness

The canonical Docker-based Toxiproxy harness remains at `dev/docker/toxiproxy`.

```bash
docker compose -f dev/docker/toxiproxy/docker-compose.yml -p citadel-toxiproxy up -d
dev/docker/toxiproxy/verify.sh
mix hardening.infrastructure_faults
```
