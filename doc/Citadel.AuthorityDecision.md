# `Citadel.AuthorityDecision`

Internal Brain authority value projected into `AuthorityDecision.v1`.

# `t`

```elixir
@type t() :: %Citadel.AuthorityDecision{
  approval_profile: String.t(),
  boundary_class: String.t(),
  contract_version: String.t(),
  decision_hash: String.t(),
  decision_id: String.t(),
  egress_profile: String.t(),
  extensions: map(),
  policy_version: String.t(),
  request_id: String.t(),
  resource_profile: String.t(),
  tenant_id: String.t(),
  trust_profile: String.t(),
  workspace_profile: String.t()
}
```

# `dump`

# `new!`

# `policy_surface`

Returns the policy-stage trust and quality surface for upper consumers.

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
