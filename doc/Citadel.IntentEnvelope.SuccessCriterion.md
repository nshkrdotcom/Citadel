# `Citadel.IntentEnvelope.SuccessCriterion`

Structured success criterion carried by `Citadel.IntentEnvelope`.

# `t`

```elixir
@type t() :: %Citadel.IntentEnvelope.SuccessCriterion{
  criterion_kind: :completion | :artifact_presence | :signal_status,
  extensions: map(),
  metric: String.t(),
  required: boolean(),
  target: term()
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
