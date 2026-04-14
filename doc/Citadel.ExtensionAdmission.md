# `Citadel.ExtensionAdmission`

Explicit admission result for one visible local service.

# `status`

```elixir
@type status() :: :admitted | :denied | :hidden | :stale
```

# `t`

```elixir
@type t() :: %Citadel.ExtensionAdmission{
  admission_epoch: non_neg_integer(),
  effective_policy_version: String.t(),
  extensions: map(),
  reason_code: String.t(),
  service_id: String.t(),
  status: status()
}
```

# `allowed_statuses`

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
