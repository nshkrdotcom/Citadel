# `Citadel.ExecutionGovernanceCompiler`

Pure compiler from existing Citadel decision values into `ExecutionGovernance.v1`.

# `compile!`

```elixir
@spec compile!(
  Citadel.AuthorityContract.AuthorityDecision.V1.t(),
  Citadel.BoundaryIntent.t(),
  Citadel.TopologyIntent.t(),
  map() | keyword()
) :: Citadel.ExecutionGovernance.V1.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
