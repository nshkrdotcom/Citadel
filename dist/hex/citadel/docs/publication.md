# Publication

Citadel publishes a welded public artifact as a derivative of the workspace
graph.

## Default Artifact

- manifest: `packaging/weld/citadel.exs`
- artifact id: `citadel`
- mode: package projection
- roots: `core/citadel_kernel`
- selected bridge closure: all `bridges/*`
- excluded by default: `apps/*`, `core/conformance`,
  `surfaces/citadel_domain_surface`, and the root tooling project

That default shape keeps the runtime-facing product packages public without
collapsing package ownership into a monolith.

## Direct Surface Publication

The workspace also contains `surfaces/citadel_domain_surface` as a separately
publishable northbound package.

That package is intentionally not part of the default welded `citadel`
artifact. It remains a direct package publication concern so the Citadel kernel
artifact and the typed host-facing surface can evolve on distinct publication
tracks inside the same monorepo.

## Release Flow

Use the repo-local Weld manifest instead of hand-built packaging steps:

```bash
mix release.prepare
mix release.track
mix release.archive
```

`mix release.track` updates the orphan-backed `projection/citadel` branch so
downstream repos can pin a real generated-source ref before any formal release
boundary exists.

`mix weld.verify` is the packet-facing publication gate. It projects the
artifact, runs verification against the generated package, and confirms that
workspace-external dependencies are canonicalized to publishable dependency
declarations. The higher-order `Jido.Integration.V2` contract slice is carried
as the in-workspace `core/jido_integration_contracts` package, so the
generated `citadel` artifact does not leak a path, git, or unpublished Hex
dependency for those modules.

## Ownership Rule

The welded artifact does not redefine the workspace architecture.

- `core/*` packages except `core/conformance` remain the public core surface
- bridge packages remain bridge packages inside the projection
- `apps/*` stay proof shells above the kernel and are not published by default
- `surfaces/citadel_domain_surface` remains a direct package publication unit,
  not part of the default welded runtime artifact
- the root workspace project stays tooling-only
