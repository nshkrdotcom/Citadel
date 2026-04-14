# `Citadel.PlanHints`

Advisory plan shaping hints attached to structured ingress.

# `t`

```elixir
@type t() :: %Citadel.PlanHints{
  budget_hints: Citadel.PlanHints.BudgetHints.t() | nil,
  candidate_steps: [Citadel.PlanHints.CandidateStep.t()],
  extensions: map(),
  preferred_targets: [Citadel.IntentEnvelope.TargetHint.t()],
  preferred_topology: Citadel.PlanHints.PreferredTopology.t() | nil
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
