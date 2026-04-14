# `Citadel.SignalIngressRebuildPolicy`

Explicit rebuild policy for `SignalIngress`.

# `t`

```elixir
@type t() :: %Citadel.SignalIngressRebuildPolicy{
  batch_interval_ms: pos_integer(),
  extensions: map(),
  high_priority_ready_slo_ms: pos_integer(),
  max_sessions_per_batch: pos_integer(),
  priority_order: [String.t()]
}
```

# `defaults`

# `dump`

# `new!`

# `priority_rank`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
