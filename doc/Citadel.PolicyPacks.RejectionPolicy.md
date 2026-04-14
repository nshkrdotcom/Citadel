# `Citadel.PolicyPacks.RejectionPolicy`

Pure policy inputs for rejection retryability and publication classification.

# `t`

```elixir
@type t() :: %Citadel.PolicyPacks.RejectionPolicy{
  denial_audit_reason_codes: [String.t()],
  derived_state_reason_codes: [String.t()],
  extensions: map(),
  governance_change_reason_codes: [String.t()],
  runtime_change_reason_codes: [String.t()]
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
