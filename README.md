<p align="center">
  <img src="assets/citadel.svg" alt="Citadel" width="220" />
</p>

# Citadel

Citadel is the host-local Brain kernel for a generic agentic OS. It accepts structured ingress at the kernel boundary, compiles Brain policy and planning decisions, preserves host-local session continuity, and projects Brain-authored packets toward the shared `jido_integration` contracts layer.

This repository is now aligned to the packet-defined non-umbrella workspace. The old single-package scaffold is gone; the package graph and ownership boundaries are the source of truth.

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
    host_surface_harness/
```

Package ownership is explicit:

- `core/*` owns values, contracts, policy packs, runtime coordination, and conformance.
- `bridges/*` owns adapter code only.
- `apps/*` owns thin proof-app composition shells and stays above the kernel.

The third proof app, `apps/host_surface_harness`, is part of the workspace from day one. It exists to prove host/kernel seams, multi-session behavior, and structured ingress above Citadel without pushing those concerns into the core.

## Toolchain And Build

Citadel is pinned to Elixir `~> 1.19` and OTP 28. The repo-level `.tool-versions` file tracks the exact bootstrap pair:

- `elixir 1.19.5-otp-28`
- `erlang 28.3`

The root Mix project is a tooling-only workspace orchestrator. Wave 1 materializes the packet-pinned workspace tooling and dependency posture explicitly:

- `{:blitz, "~> 0.2.0", runtime: false}` for workspace fanout
- `{:weld, "~> 0.4.0", runtime: false}` for repo-local package projection and release preparation
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
- `mix monorepo.dialyzer` fans out `mix dialyzer --halt-exit-status` across the real workspace graph through Blitz, so any Dialyzer warning fails the build.
- `.github/workflows/ci.yml` runs format, compile, packet seam lint, strict lint, Dialyzer, and tests as separate CI steps.

Publication is now finalized as a derivative workspace boundary. The repo-local
Weld manifest lives at `packaging/weld/citadel.exs`, projects the public
`citadel` artifact in package-projection mode, keeps `apps/*` and
`core/conformance` out of the default artifact, and preserves package
ownership instead of flattening the workspace into a monolith.

Common publication commands:

```bash
mix weld.inspect packaging/weld/citadel.exs
mix weld.verify packaging/weld/citadel.exs
mix weld.release.prepare packaging/weld/citadel.exs
mix weld.release.archive packaging/weld/citadel.exs
```

## Shared Contract Strategy

Wave 1 does not freeze the final public dependency strategy for `:jido_integration_v2_contracts`, but it does make the placeholder explicit in the packages that will need it first:

- `core/citadel_core`
- `bridges/invocation_bridge`
- `bridges/projection_bridge`
- `core/conformance`

Those packages resolve the dependency through `build_support/dependency_resolver.exs`. Local development prefers the packet path:

- `/home/home/p/g/n/jido_integration/core/contracts`

If that path is unavailable, the resolver falls back to the published package placeholder requirement so Wave 2 can freeze the versioning rule explicitly instead of inheriting it by accident.

## Documentation

The packet that drives this repo lives at:

- `/home/home/p/g/n/jido_brainstorm/nshkrdotcom/docs/20260409/citadel_ground_up_design_docset`

Local workspace docs now live in:

- `README.md`
- `docs/README.md`
- `docs/workspace_topology.md`
- `docs/shared_contract_dependency_strategy.md`
- package-level `README.md` files under every `core/*`, `bridges/*`, and `apps/*` package

## Fault Injection Harness

The canonical Docker-based Toxiproxy harness remains at `dev/docker/toxiproxy`.

```bash
docker compose -f dev/docker/toxiproxy/docker-compose.yml -p citadel-toxiproxy up -d
dev/docker/toxiproxy/verify.sh
mix hardening.infrastructure_faults
```
