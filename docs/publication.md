# Publication

Citadel publishes a welded public artifact as a derivative of the workspace
graph.

## Default Artifact

- manifest: `packaging/weld/citadel.exs`
- artifact id: `citadel`
- mode: package projection
- roots: `core/citadel_runtime`
- selected bridge closure: all `bridges/*`
- excluded by default: `apps/*`, `core/conformance`, and the root tooling project

That default shape keeps the runtime-facing product packages public without
collapsing package ownership into a monolith.

## Release Flow

Use the repo-local Weld manifest instead of hand-built packaging steps:

```bash
mix weld.inspect packaging/weld/citadel.exs
mix weld.verify packaging/weld/citadel.exs
mix weld.release.prepare packaging/weld/citadel.exs
mix weld.release.archive packaging/weld/citadel.exs
```

`mix weld.verify` is the packet-facing publication gate. It projects the
artifact, runs verification against the generated package, and confirms that
workspace-external dependencies are canonicalized to publishable dependency
declarations. The higher-order `Jido.Integration.V2` contract slice is carried
as the in-workspace `core/jido_integration_v2_contracts` package, so the
generated `citadel` artifact does not leak a path, git, or unpublished Hex
dependency for those modules.

## Ownership Rule

The welded artifact does not redefine the workspace architecture.

- `core/*` packages except `core/conformance` remain the public core surface
- bridge packages remain bridge packages inside the projection
- `apps/*` stay proof shells above the kernel and are not published by default
- the root workspace project stays tooling-only
