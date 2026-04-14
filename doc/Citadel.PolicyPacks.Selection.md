# `Citadel.PolicyPacks.Selection`

Deterministic output of policy-pack profile selection.

# `t`

```elixir
@type t() :: %Citadel.PolicyPacks.Selection{
  extensions: map(),
  pack_id: String.t(),
  policy_epoch: non_neg_integer(),
  policy_version: String.t(),
  priority: non_neg_integer(),
  profiles: Citadel.PolicyPacks.Profiles.t(),
  rejection_policy: Citadel.PolicyPacks.RejectionPolicy.t()
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
