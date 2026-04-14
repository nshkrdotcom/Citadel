# `Citadel.SessionActivationPolicy`

Explicit bounded cold-boot or mass-recovery activation policy.

# `t`

```elixir
@type t() :: %Citadel.SessionActivationPolicy{
  extensions: map(),
  max_concurrent_activations: pos_integer(),
  priority_order: [String.t()],
  refill_interval_ms: pos_integer()
}
```

# `defaults`

# `dump`

# `new!`

# `priority_rank`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
