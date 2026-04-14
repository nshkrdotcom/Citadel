# `Citadel.IntentEnvelope.DesiredOutcome`

Structured desired-outcome record carried by `Citadel.IntentEnvelope`.

# `t`

```elixir
@type t() :: %Citadel.IntentEnvelope.DesiredOutcome{
  extensions: map(),
  outcome_kind: :invoke_capability | :inspect_scope | :maintain_session,
  requested_capabilities: [String.t()],
  result_kind: String.t(),
  subject_selectors: [String.t()]
}
```

# `allowed_outcome_kinds`

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
