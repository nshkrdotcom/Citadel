# `Citadel.Step`

One explicit planned step.

# `t`

```elixir
@type t() :: %Citadel.Step{
  allowed_operations: [String.t()],
  boundary_intent: Citadel.BoundaryIntent.t() | nil,
  capability_id: String.t(),
  extensions: map(),
  kind: String.t(),
  step_id: String.t(),
  target_hints: [Citadel.IntentEnvelope.TargetHint.t()]
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
