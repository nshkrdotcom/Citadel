# `Citadel.BridgeCircuit`

Pure bridge-side circuit state keyed by the policy-selected downstream scope.

# `scope_state`

```elixir
@type scope_state() :: %{
  status: status(),
  failure_timestamps: [non_neg_integer()],
  opened_at_ms: non_neg_integer() | nil,
  half_open_inflight: non_neg_integer()
}
```

# `status`

```elixir
@type status() :: :closed | :open | :half_open
```

# `t`

```elixir
@type t() :: %Citadel.BridgeCircuit{
  now_ms_fun: (-&gt; non_neg_integer()),
  policy: Citadel.BridgeCircuitPolicy.t(),
  scope_states: %{required(String.t()) =&gt; scope_state()}
}
```

# `allow`

```elixir
@spec allow(t(), String.t()) :: {:ok, t()} | {{:error, :circuit_open}, t()}
```

# `new!`

```elixir
@spec new!(keyword()) :: t()
```

# `record_failure`

```elixir
@spec record_failure(t(), String.t()) :: t()
```

# `record_success`

```elixir
@spec record_success(t(), String.t()) :: t()
```

# `scope_state`

```elixir
@spec scope_state(t(), String.t()) :: scope_state()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
