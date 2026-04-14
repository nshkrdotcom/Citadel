# `Citadel.MemoryBridge`

Advisory memory bridge keyed lexically by `memory_id`.

# `t`

```elixir
@type t() :: %Citadel.MemoryBridge{
  circuit_policy: Citadel.BridgeCircuitPolicy.t(),
  downstream: module(),
  state_ref: Citadel.BridgeState.state_ref()
}
```

# `advisory_modes`

```elixir
@spec advisory_modes() :: [atom()]
```

# `default_circuit_policy`

```elixir
@spec default_circuit_policy() :: Citadel.BridgeCircuitPolicy.t()
```

# `get_memory_record`

```elixir
@spec get_memory_record(t(), String.t(), Citadel.Ports.Memory.lookup_options()) ::
  {:ok, Citadel.MemoryRecord.t() | nil, t()} | {:error, atom(), t()}
```

# `manifest`

```elixir
@spec manifest() :: map()
```

# `new!`

```elixir
@spec new!(keyword()) :: t()
```

# `put_memory_record`

```elixir
@spec put_memory_record(t(), Citadel.MemoryRecord.t()) ::
  {:ok, %{write_guarantee: :stable_put_by_id | :best_effort}, t()}
  | {:error, atom(), t()}
```

# `rank_memory_records`

```elixir
@spec rank_memory_records(t(), Citadel.Ports.Memory.rank_options()) ::
  {:ok, [Citadel.MemoryRecord.t()], t()} | {:error, atom(), t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
