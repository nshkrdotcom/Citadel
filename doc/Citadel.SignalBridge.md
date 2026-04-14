# `Citadel.SignalBridge`

Normalizes non-boundary runtime signals into `Citadel.RuntimeObservation`.

# `raw_signal`

```elixir
@type raw_signal() :: Citadel.Ports.SignalSource.raw_signal()
```

# `t`

```elixir
@type t() :: %Citadel.SignalBridge{adapter: module()}
```

# `manifest`

```elixir
@spec manifest() :: map()
```

# `new!`

```elixir
@spec new!(keyword()) :: t()
```

# `normalize_signal`

```elixir
@spec normalize_signal(t(), raw_signal()) ::
  {:ok, Citadel.RuntimeObservation.t(), t()} | {:error, atom(), t()}
```

# `normalized_signal_fields`

```elixir
@spec normalized_signal_fields() :: [atom()]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
