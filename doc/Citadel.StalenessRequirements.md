# `Citadel.StalenessRequirements`

Explicit replay-safe stale-check contract for one persisted action.

# `t`

```elixir
@type t() :: %Citadel.StalenessRequirements{
  boundary_epoch: non_neg_integer() | nil,
  extensions: map(),
  policy_epoch: non_neg_integer() | nil,
  project_binding_epoch: non_neg_integer() | nil,
  required_binding_id: String.t() | nil,
  required_boundary_ref: String.t() | nil,
  scope_catalog_epoch: non_neg_integer() | nil,
  service_admission_epoch: non_neg_integer() | nil,
  snapshot_seq: non_neg_integer() | nil,
  topology_epoch: non_neg_integer() | nil
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
