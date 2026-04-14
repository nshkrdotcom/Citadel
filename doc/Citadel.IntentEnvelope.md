# `Citadel.IntentEnvelope`

Frozen Wave 3 structured ingress contract for Citadel.

# `t`

```elixir
@type t() :: %Citadel.IntentEnvelope{
  constraints: Citadel.IntentEnvelope.Constraints.t(),
  desired_outcome: Citadel.IntentEnvelope.DesiredOutcome.t(),
  extensions: map(),
  intent_envelope_id: String.t(),
  plan_hints: Citadel.PlanHints.t() | nil,
  resolution_provenance: Citadel.ResolutionProvenance.t() | nil,
  risk_hints: [Citadel.IntentEnvelope.RiskHint.t()],
  scope_selectors: [Citadel.IntentEnvelope.ScopeSelector.t()],
  success_criteria: [Citadel.IntentEnvelope.SuccessCriterion.t()],
  target_hints: [Citadel.IntentEnvelope.TargetHint.t()]
}
```

# `dump`

# `frozen_subschemas`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
