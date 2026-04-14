# `Citadel.IntentEnvelope.Constraints`

Structured planning and execution constraints carried by `Citadel.IntentEnvelope`.

# `t`

```elixir
@type t() :: %Citadel.IntentEnvelope.Constraints{
  allowed_boundary_classes: [String.t()],
  allowed_service_ids: [String.t()],
  boundary_requirement:
    :reuse_existing | :fresh_or_reuse | :fresh_only | :no_boundary,
  extensions: map(),
  forbidden_service_ids: [String.t()],
  max_steps: pos_integer(),
  review_required: boolean()
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
