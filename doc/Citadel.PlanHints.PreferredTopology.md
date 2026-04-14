# `Citadel.PlanHints.PreferredTopology`

Preferred-topology hint used inside `Citadel.PlanHints`.

# `t`

```elixir
@type t() :: %Citadel.PlanHints.PreferredTopology{
  coordination_mode: :single_target | :parallel_fanout | :local_only,
  extensions: map(),
  routing_hints: map(),
  session_mode: :attached | :detached | :stateless
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
