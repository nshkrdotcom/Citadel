# `Citadel.BoundaryBridge.BoundaryProjectionAdapter`

Isolates the boundary-intent projection shape at the bridge edge.

# `metadata`

```elixir
@type metadata() :: Citadel.Ports.BoundaryLifecycle.boundary_intent_metadata()
```

# `projection`

```elixir
@type projection() :: %{
  required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
}
```

# `project!`

```elixir
@spec project!(Citadel.BoundaryIntent.t(), metadata()) :: projection()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
