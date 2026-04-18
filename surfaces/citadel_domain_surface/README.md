# Citadel Domain Surface

`Citadel.DomainSurface` is the typed host-facing command, query, route, and
capability boundary above the Citadel kernel.

It now lives inside the Citadel workspace as a separate publishable package:

- workspace home: `surfaces/citadel_domain_surface`
- Mix app: `:citadel_domain_surface`
- public namespace: `Citadel.DomainSurface`

This package is intentionally separate from Citadel kernel `core/*` packages
and from Citadel `bridges/*` packages. It is a northbound surface package.

## Scope

- typed commands
- typed queries
- typed routes
- capability catalogs and tool manifests
- host-friendly error vocabulary
- bounded admin and maintenance surfaces
- explicit adapter seams into Citadel and optional lower integration

## Non-Scope

- Brain kernel policy ownership
- durable lower execution truth
- a shadow control plane
- raw transport or runtime mechanics

## Stack Position

```text
host app / host shell
  -> Citadel.DomainSurface
      -> Citadel.HostIngress / Citadel.QueryBridge
          -> Citadel kernel and runtime packages
              -> jido_integration / execution_plane
```

## Workspace Dependencies

This package no longer depends on the welded `citadel/dist/hex/citadel`
projection during normal local development. It depends directly on Citadel
workspace packages:

- `core/citadel_governance`
- `core/citadel_kernel`
- `bridges/host_ingress_bridge`
- `bridges/query_bridge`

## Example

```elixir
{:ok, command} =
  Citadel.DomainSurface.Examples.ProvingGround.compile_workspace(
    %{workspace_id: "workspace/main"},
    idempotency_key: "cmd-1",
    metadata: %{source: "ui"}
  )

{:ok, accepted} =
  Citadel.DomainSurface.submit(
    Citadel.DomainSurface.Examples.ProvingGround.Commands.CompileWorkspace,
    %{workspace_id: "workspace/main"},
    idempotency_key: "cmd-1",
    context: %{trace_id: "trace-1"},
    kernel_runtime: {Citadel.DomainSurface.Adapters.CitadelAdapter, runtime_opts}
  )
```

## Development

From this package directory:

```bash
mix deps.get
mix format
mix compile --warnings-as-errors
mix test
mix static.analysis
```

Fault-injection coverage is opt-in and reuses the canonical Citadel Toxiproxy
harness:

```bash
mix hardening.infrastructure_faults
```

## Notes

- The historical standalone repo at `/home/home/p/g/n/jido_domain` remains as
  reference only.
- The default welded `citadel` artifact does not absorb this package.
- This package is intended to be publishable directly if the workspace later
  chooses to release it independently of the default welded Citadel artifact.
