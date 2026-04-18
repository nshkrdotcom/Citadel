# Citadel Conformance

Status: Wave 7 black-box conformance.

## Owns

- cross-package black-box fixture ownership
- contract conformance coverage
- bridge and app composition verification
- frozen-seam regression guards
- published-artifact compatibility gating for shared public contracts

## Dependencies

- public `core/*`, `bridges/*`, and `apps/*` package APIs
- public `core/jido_integration_contracts` fixtures and types

## Wave 7 Posture

Conformance stays black-box. It proves the workspace still composes through
public seams only, exercises the host-surface harness without reaching through
private helpers, and carries an explicit release-artifact gate so local
path-only contract changes do not become the only verified compatibility mode.

Run the published-or-staged artifact gate with:

`bin/test_published_contracts.sh`
