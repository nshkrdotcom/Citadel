# `Citadel.PolicyPacks.Profiles`

Explicit decision-shaping profiles selected from one policy pack.

# `t`

```elixir
@type t() :: %Citadel.PolicyPacks.Profiles{
  approval_profile: String.t(),
  boundary_class: String.t(),
  egress_profile: String.t(),
  extensions: map(),
  resource_profile: String.t(),
  trust_profile: String.t(),
  workspace_profile: String.t()
}
```

# `dump`

# `new!`

# `policy_surface`

Returns the stable policy-stage surface used by Citadel selectors and upper consumers.

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
