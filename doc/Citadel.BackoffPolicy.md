# `Citadel.BackoffPolicy`

Explicit deterministic retry schedule contract.

# `jitter_mode`

```elixir
@type jitter_mode() :: :none | :entry_stable
```

# `strategy`

```elixir
@type strategy() :: :fixed | :linear | :exponential
```

# `t`

```elixir
@type t() :: %Citadel.BackoffPolicy{
  base_delay_ms: non_neg_integer(),
  extensions: map(),
  jitter_mode: jitter_mode(),
  jitter_window_ms: non_neg_integer(),
  linear_step_ms: non_neg_integer() | nil,
  max_delay_ms: non_neg_integer() | nil,
  multiplier: pos_integer() | nil,
  strategy: strategy()
}
```

# `allowed_jitter_modes`

# `allowed_strategies`

# `compute_delay_ms!`

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
