# `Citadel.BridgeState`

Process-backed owner for bridge circuit state and optional deduplication receipts.

# `operation_token`

```elixir
@type operation_token() :: reference()
```

# `state`

```elixir
@type state() :: %{
  circuit: Citadel.BridgeCircuit.t(),
  receipts_by_dedupe_key: %{optional(String.t()) =&gt; term()},
  pending_operations: %{optional(operation_token()) =&gt; map()},
  pending_dedupe_keys: %{optional(String.t()) =&gt; operation_token()},
  monitor_refs: %{optional(reference()) =&gt; operation_token()}
}
```

# `state_ref`

```elixir
@type state_ref() :: %Citadel.BridgeState.Ref{
  name: GenServer.name(),
  start_opts: keyword()
}
```

# `state_server`

```elixir
@type state_server() :: state_ref() | GenServer.server()
```

# `begin_operation`

```elixir
@spec begin_operation(state_server(), String.t(), keyword()) ::
  {:ok, operation_token()}
  | {:duplicate, term()}
  | {:error, :circuit_open | :submission_inflight}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `ensure_started!`

```elixir
@spec ensure_started!(keyword()) :: GenServer.server()
```

# `finish_operation`

```elixir
@spec finish_operation(
  state_server(),
  operation_token(),
  {:accepted, term()} | {:rejected, term()} | {:ok, term()} | {:error, atom()}
) ::
  {:accepted, term()}
  | {:rejected, term()}
  | {:ok, term()}
  | {:error, atom() | :operation_not_found}
```

# `new_ref!`

```elixir
@spec new_ref!(keyword()) :: state_ref()
```

# `server`

```elixir
@spec server(state_server()) :: GenServer.server()
```

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
