# `Citadel.PolicyPacks.PolicyPack`

One explicit policy pack plus its selector, profile set, and rejection policy.

# `t`

```elixir
@type t() :: %Citadel.PolicyPacks.PolicyPack{
  extensions: map(),
  pack_id: String.t(),
  policy_epoch: non_neg_integer(),
  policy_version: String.t(),
  priority: non_neg_integer(),
  profiles: Citadel.PolicyPacks.Profiles.t(),
  rejection_policy: Citadel.PolicyPacks.RejectionPolicy.t(),
  selector: Citadel.PolicyPacks.Selector.t()
}
```

# `dump`

# `matches?`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
