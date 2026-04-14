# `Citadel.TraceBridge`

AITrace-facing trace publication bridge consuming canonical `Citadel.TraceEnvelope` values.

# `reason_code`

```elixir
@type reason_code() ::
  :unavailable
  | :timeout
  | :rate_limited
  | :invalid_envelope
  | :backend_rejected
  | :circuit_open
  | :unknown
```

# `export_targets`

```elixir
@spec export_targets() :: [atom()]
```

# `failure_reason_codes`

```elixir
@spec failure_reason_codes() :: [atom(), ...]
```

# `manifest`

```elixir
@spec manifest() :: map()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
