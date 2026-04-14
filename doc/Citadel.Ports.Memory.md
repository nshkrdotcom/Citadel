# `Citadel.Ports.Memory`

Advisory memory seam keyed lexically by `memory_id`.

# `lookup_option`

```elixir
@type lookup_option() :: {:scope_id, String.t()}
```

# `lookup_options`

```elixir
@type lookup_options() :: [lookup_option()]
```

# `rank_option`

```elixir
@type rank_option() ::
  {:scope_id, String.t()}
  | {:session_id, String.t()}
  | {:kind, String.t()}
  | {:limit, pos_integer()}
```

# `rank_options`

```elixir
@type rank_options() :: [rank_option()]
```

# `get_memory_record`

```elixir
@callback get_memory_record(String.t(), lookup_options()) ::
  {:ok, Citadel.MemoryRecord.t() | nil} | {:error, atom()}
```

# `put_memory_record`

```elixir
@callback put_memory_record(Citadel.MemoryRecord.t()) ::
  {:ok, %{write_guarantee: :stable_put_by_id | :best_effort}} | {:error, atom()}
```

# `rank_memory_records`

```elixir
@callback rank_memory_records(rank_options()) ::
  {:ok, [Citadel.MemoryRecord.t()]} | {:error, atom()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
