# `Citadel.BridgeCircuitPolicy`

Explicit fail-fast policy for outbound bridge calls.

# `t`

```elixir
@type t() :: %Citadel.BridgeCircuitPolicy{
  cooldown_ms: pos_integer(),
  extensions: map(),
  failure_threshold: pos_integer(),
  half_open_max_inflight: pos_integer(),
  scope_key_mode: String.t(),
  window_ms: pos_integer()
}
```

# `allowed_scope_key_modes`

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
