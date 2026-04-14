# `Citadel.BoundaryBridge`

Explicit boundary lifecycle seam for Brain-side boundary direction and lower lifecycle facts.

# `t`

```elixir
@type t() :: %Citadel.BoundaryBridge{
  circuit_policy: Citadel.BridgeCircuitPolicy.t(),
  downstream: module(),
  projection_adapter: module(),
  state_ref: Citadel.BridgeState.state_ref()
}
```

# `boundary_metadata_fields`

```elixir
@spec boundary_metadata_fields() :: [atom()]
```

# `default_circuit_policy`

```elixir
@spec default_circuit_policy() :: Citadel.BridgeCircuitPolicy.t()
```

# `manifest`

```elixir
@spec manifest() :: map()
```

# `new!`

```elixir
@spec new!(keyword()) :: t()
```

# `normalize_attach_grant`

```elixir
@spec normalize_attach_grant(
  t(),
  Citadel.Ports.BoundaryLifecycle.attach_grant_source()
) ::
  {:ok, Citadel.AttachGrant.V1.t(), t()}
```

# `normalize_boundary_lease`

```elixir
@spec normalize_boundary_lease(
  t(),
  Citadel.Ports.BoundaryLifecycle.boundary_lease_source()
) :: {:ok, Citadel.BoundaryLeaseView.t(), t()}
```

# `normalize_boundary_session`

```elixir
@spec normalize_boundary_session(
  t(),
  Citadel.Ports.BoundaryLifecycle.boundary_session_source()
) :: {:ok, Citadel.BoundarySessionDescriptor.V1.t(), t()}
```

# `submit_boundary_intent`

```elixir
@spec submit_boundary_intent(
  t(),
  Citadel.BoundaryIntent.t(),
  Citadel.Ports.BoundaryLifecycle.boundary_intent_metadata()
) :: {:ok, String.t(), t()} | {:error, atom(), t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
