# `Citadel.Objective`

Normalized structured objective derived from `IntentEnvelope`.

# `t`

```elixir
@type t() :: %Citadel.Objective{
  constraints: Citadel.IntentEnvelope.Constraints.t(),
  extensions: map(),
  intent_spec: map(),
  kind: String.t(),
  objective_id: String.t(),
  priority: :low | :normal | :high | :urgent,
  provenance: Citadel.ResolutionProvenance.t() | nil,
  success_criteria: [Citadel.IntentEnvelope.SuccessCriterion.t()]
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
