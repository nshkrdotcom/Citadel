# `Citadel.ProjectionBridge`

Explicit northbound publication bridge for review projections and derived-state attachments.

# `downstream_metadata`

```elixir
@type downstream_metadata() :: %{
  :entry_id =&gt; String.t(),
  :payload_kind =&gt; String.t(),
  optional(:causal_group_id) =&gt; String.t()
}
```

# `t`

```elixir
@type t() :: %Citadel.ProjectionBridge{
  circuit_policy: Citadel.BridgeCircuitPolicy.t(),
  derived_state_attachment_adapter: module(),
  downstream: module(),
  review_projection_adapter: module(),
  state_ref: Citadel.BridgeState.state_ref()
}
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

# `publish_derived_state_attachment`

```elixir
@spec publish_derived_state_attachment(
  t(),
  Jido.Integration.V2.DerivedStateAttachment.t(),
  Citadel.ActionOutboxEntry.t()
) :: {:ok, String.t(), t()} | {:error, atom(), t()}
```

# `publish_review_projection`

```elixir
@spec publish_review_projection(
  t(),
  Jido.Integration.V2.ReviewProjection.t() | Citadel.RuntimeObservation.t(),
  Citadel.ActionOutboxEntry.t()
) :: {:ok, String.t(), t()} | {:error, atom(), t()}
```

# `shared_contract_strategy`

```elixir
@spec shared_contract_strategy() :: :bridge_edge_adapters
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
