# `Citadel.Runtime.TracePublisher`

Best-effort bounded trace publisher used after commit.

The runtime owns the process in the default application tree and session
startup wires it by default through `Citadel.Runtime.start_session/1`.

# `buffer_depths`

```elixir
@type buffer_depths() :: %{
  depth: non_neg_integer(),
  protected_depth: non_neg_integer(),
  regular_depth: non_neg_integer()
}
```

# `state`

```elixir
@type state() :: %{
  trace_port: module(),
  buffer: Citadel.Runtime.TracePublisher.Buffer.t(),
  batch_size: pos_integer(),
  flush_interval_ms: non_neg_integer(),
  drain_scheduled?: boolean()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `publish_trace`

```elixir
@spec publish_trace(GenServer.server(), Citadel.TraceEnvelope.t()) ::
  :ok | {:error, atom()}
```

# `publish_traces`

```elixir
@spec publish_traces(GenServer.server(), [Citadel.TraceEnvelope.t()]) ::
  :ok | {:error, atom()}
```

# `snapshot`

```elixir
@spec snapshot(GenServer.server()) :: buffer_depths()
```

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
