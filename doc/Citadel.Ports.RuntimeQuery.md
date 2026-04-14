# `Citadel.Ports.RuntimeQuery`

Rehydrates durable lower truth into normalized Citadel read models.

# `boundary_session_query`

```elixir
@type boundary_session_query() :: %{
  :downstream_scope =&gt; String.t(),
  optional(:boundary_ref) =&gt; String.t(),
  optional(:boundary_session_id) =&gt; String.t(),
  optional(:session_id) =&gt; String.t(),
  optional(:tenant_id) =&gt; String.t(),
  optional(:target_id) =&gt; String.t()
}
```

# `boundary_session_result`

```elixir
@type boundary_session_result() ::
  {:ok, Citadel.BoundarySessionDescriptor.V1.t()} | {:error, atom()}
```

# `runtime_observation_query`

```elixir
@type runtime_observation_query() :: %{
  :downstream_scope =&gt; String.t(),
  optional(:request_id) =&gt; String.t(),
  optional(:session_id) =&gt; String.t(),
  optional(:signal_id) =&gt; String.t(),
  optional(:signal_cursor) =&gt; String.t(),
  optional(:runtime_ref_id) =&gt; String.t()
}
```

# `runtime_observation_result`

```elixir
@type runtime_observation_result() ::
  {:ok, Citadel.RuntimeObservation.t()} | {:error, atom()}
```

# `fetch_boundary_session`

```elixir
@callback fetch_boundary_session(boundary_session_query()) :: boundary_session_result()
```

# `fetch_runtime_observation`

```elixir
@callback fetch_runtime_observation(runtime_observation_query()) ::
  runtime_observation_result()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
