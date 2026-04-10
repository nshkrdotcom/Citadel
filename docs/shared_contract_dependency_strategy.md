# Shared Contract Dependency Strategy

Wave 1 makes the `:jido_integration_v2_contracts` dependency strategy explicit without freezing the final public versioning rule yet.

## Packages Carrying The Placeholder Stub

The packages that will need the shared contracts early already declare the dependency explicitly in their `mix.exs` files:

- `core/citadel_core`
- `bridges/invocation_bridge`
- `bridges/projection_bridge`
- `core/conformance`

## Resolution Order

`build_support/dependency_resolver.exs` resolves `:jido_integration_v2_contracts` in this order:

1. `CITADEL_JIDO_INTEGRATION_CONTRACTS_PATH`
2. `JIDO_INTEGRATION_PATH/core/contracts`
3. `/home/home/p/g/n/jido_integration/core/contracts`
4. published placeholder requirement `~> 0.1.0`

That keeps local cross-repo iteration easy while preserving an explicit fallback requirement for later public verification.

## Wave Boundary

Wave 1 intentionally stops at explicit placeholders and build surfaces. Wave 2 freezes:

- which packages consume already-existing higher-order shared contracts directly
- the supported published version range for `:jido_integration_v2_contracts`
- where lower execution seams remain local Citadel definitions until Wave 5

No package in Wave 1 should assume that the lower execution packet family already exists downstream.
