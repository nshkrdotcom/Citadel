# `Citadel.ScopeRef`

Explicit host-local scope reference for kernel interpretation.

# `t`

```elixir
@type t() :: %Citadel.ScopeRef{
  catalog_epoch: non_neg_integer(),
  environment: String.t(),
  extensions: map(),
  scope_id: String.t(),
  scope_kind: String.t(),
  workspace_root: String.t()
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
