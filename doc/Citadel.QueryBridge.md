# `Citadel.QueryBridge`

Rehydrates durable lower truth into normalized Citadel read models.

# `t`

```elixir
@type t() :: %Citadel.QueryBridge{
  circuit_policy: Citadel.BridgeCircuitPolicy.t(),
  downstream: module(),
  state_ref: Citadel.BridgeState.state_ref()
}
```

# `default_circuit_policy`

```elixir
@spec default_circuit_policy() :: Citadel.BridgeCircuitPolicy.t()
```

# `fetch_boundary_session`

```elixir
@spec fetch_boundary_session(t(), Citadel.Ports.RuntimeQuery.boundary_session_query()) ::
  {:ok, Citadel.BoundarySessionDescriptor.V1.t(), t()} | {:error, atom(), t()}
```

# `fetch_runtime_observation`

```elixir
@spec fetch_runtime_observation(
  t(),
  Citadel.Ports.RuntimeQuery.runtime_observation_query()
) ::
  {:ok, Citadel.RuntimeObservation.t(), t()} | {:error, atom(), t()}
```

# `manifest`

```elixir
@spec manifest() :: map()
```

# `new!`

```elixir
@spec new!(keyword()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
