# `Citadel.Plan`

Ordered plan for one objective.

# `t`

```elixir
@type t() :: %Citadel.Plan{
  budget_policy: map(),
  extensions: map(),
  objective_id: String.t(),
  plan_id: String.t(),
  selection_mode: String.t(),
  steps: [Citadel.Step.t()]
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
