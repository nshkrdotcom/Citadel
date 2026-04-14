# `Citadel.IntentEnvelope.RiskHint`

Structured risk hint carried by `Citadel.IntentEnvelope`.

# `t`

```elixir
@type t() :: %Citadel.IntentEnvelope.RiskHint{
  extensions: map(),
  requires_governance: boolean(),
  risk_code: String.t(),
  severity: :low | :medium | :high | :critical
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
