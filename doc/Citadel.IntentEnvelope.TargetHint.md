# `Citadel.IntentEnvelope.TargetHint`

Structured target hint carried by `Citadel.IntentEnvelope`.

# `t`

```elixir
@type t() :: %Citadel.IntentEnvelope.TargetHint{
  coordination_mode_preference:
    :single_target | :parallel_fanout | :local_only | nil,
  extensions: map(),
  preferred_boundary_class: String.t() | nil,
  preferred_service_id: String.t() | nil,
  preferred_target_id: String.t() | nil,
  routing_tags: [String.t()],
  session_mode_preference: :attached | :detached | :stateless | nil,
  target_kind: String.t()
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
