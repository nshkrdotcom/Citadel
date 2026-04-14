# `Citadel.DecisionSnapshot`

Immutable aggregate decision snapshot captured before a pure decision pass.

# `t`

```elixir
@type t() :: %Citadel.DecisionSnapshot{
  boundary_epoch: non_neg_integer(),
  captured_at: DateTime.t(),
  extensions: map(),
  policy_epoch: non_neg_integer(),
  policy_version: String.t(),
  project_binding_epoch: non_neg_integer(),
  scope_catalog_epoch: non_neg_integer(),
  service_admission_epoch: non_neg_integer(),
  snapshot_seq: non_neg_integer(),
  topology_epoch: non_neg_integer()
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
