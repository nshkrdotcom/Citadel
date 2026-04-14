# `Citadel.KernelEpochUpdate`

Explicit constituent epoch update emitted into `KernelSnapshot`.

# `constituent`

```elixir
@type constituent() ::
  :policy_epoch
  | :topology_epoch
  | :scope_catalog_epoch
  | :service_admission_epoch
  | :project_binding_epoch
  | :boundary_epoch
```

# `t`

```elixir
@type t() :: %Citadel.KernelEpochUpdate{
  constituent: constituent(),
  epoch: non_neg_integer(),
  extensions: map(),
  source_owner: String.t(),
  updated_at: DateTime.t()
}
```

# `allowed_constituents`

# `dump`

# `extension_rule`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
