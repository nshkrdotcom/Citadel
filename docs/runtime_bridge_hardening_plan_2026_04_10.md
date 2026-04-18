# Runtime And Bridge Hardening Plan

Date: `2026-04-10`

## Verified Findings

- `BridgeState` ownership is still embedded in bridge structs as a live server reference, so bridge instances can outlive the state process that they depend on.
- The bridge packages still expose trap arities that only raise, while advertising behaviour compliance that implies those entrypoints are valid.
- `HostSurfaceHarness.submit_envelope/4` still claims session ownership directly on the accept path, even when a live `SessionServer` already owns the session.
- `HostSurfaceHarness.deliver_signal/3` still sends raw messages directly to session pids instead of using a public `SessionServer` API.
- `IntentMappingConstraints` still produces plain topology maps; there is no canonical helper that produces a `Citadel.TopologyIntent` with an id.
- `Citadel.Kernel.start_session/1` still does not inject the default `TracePublisher`, so normal runtime startup drops trace families silently.
- `HostSurfaceHarness` policy selection is decoupled from the runtime `PolicyCache`, so host-surface decisions can drift from the active runtime policy epoch and version.
- The reported `core/conformance` gap is stale. The repo already contains cross-layer tests, but those tests need to be extended to cover the hardening work below.

## Design Direction

- Bridge state must be restart-safe by name and bridge calls must not retain raw pids as their source of truth.
- Stateful bridge modules must stop pretending to be stateless behaviour implementations.
- Host-surface writes must always route through the live session owner when one exists.
- Session observation delivery must use public `SessionServer` APIs, not private mailbox formats.
- Core mapping code must provide first-class constructors for typed topology intent generation.
- Runtime defaults must wire observability on by default.
- Host-surface policy decisions must align with the active runtime policy snapshot when one is available.

## Checklist

- [x] Add red tests that prove bridge instances survive `BridgeState` process loss without stale-pid failures.
- [x] Add red tests that prove live-owner accept flow does not rotate `owner_incarnation`.
- [x] Add red tests that prove host observation delivery uses a public `SessionServer` API.
- [x] Add red tests that prove topology-intent construction is available from `IntentEnvelope` mappings.
- [x] Add red tests that prove `Citadel.Kernel.start_session/1` wires the default trace publisher.
- [x] Add red tests that prove host-surface policy selection stays aligned with the active runtime policy snapshot.
- [x] Refactor `BridgeState` into a restart-safe named reference owned by bridge structs.
- [x] Update all bridge packages that currently retain raw `BridgeState` servers to use the restart-safe reference.
- [x] Remove the bridge trap arities and stop declaring misleading behaviour compliance on stateful bridge modules.
- [x] Introduce public `SessionServer` APIs for observation ingestion and host acceptance/touch semantics.
- [x] Route `HostSurfaceHarness` accept and signal-delivery paths through those public `SessionServer` APIs when a live owner exists.
- [x] Align `HostSurfaceHarness` policy selection with the active runtime policy snapshot when one is available.
- [x] Add a canonical typed topology-intent builder in core and cover it in package tests.
- [x] Inject `Citadel.Kernel.TracePublisher` by default from `Citadel.Kernel.start_session/1`.
- [x] Extend cross-layer coverage for the live-owner path and runtime coverage for trace wiring.
- [ ] Run `mix ci` and fix any fallout.
- [ ] Commit and push the completed hardening set.
