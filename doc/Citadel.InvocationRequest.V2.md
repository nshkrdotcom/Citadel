# `Citadel.InvocationRequest.V2`

Successor Citadel-owned invoke seam with typed execution-governance carriage.

# `t`

```elixir
@type t() :: %Citadel.InvocationRequest.V2{
  actor_id: String.t(),
  allowed_operations: [String.t(), ...],
  authority_packet: Citadel.AuthorityContract.AuthorityDecision.V1.t(),
  boundary_intent: Citadel.BoundaryIntent.t(),
  execution_governance: Citadel.ExecutionGovernance.V1.t(),
  extensions: %{
    required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
  },
  invocation_request_id: String.t(),
  request_id: String.t(),
  schema_version: pos_integer(),
  selected_step_id: String.t(),
  session_id: String.t(),
  target_id: String.t(),
  target_kind: String.t(),
  tenant_id: String.t(),
  topology_intent: Citadel.TopologyIntent.t(),
  trace_id: String.t()
}
```

# `authority_packet_module`

```elixir
@spec authority_packet_module() :: module()
```

# `dump`

```elixir
@spec dump(t()) :: map()
```

# `execution_governance_module`

```elixir
@spec execution_governance_module() :: module()
```

# `new`

```elixir
@spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
```

# `new!`

```elixir
@spec new!(t() | map() | keyword()) :: t()
```

# `required_fields`

```elixir
@spec required_fields() :: [atom()]
```

# `schema`

```elixir
@spec schema() :: keyword()
```

# `schema_version`

```elixir
@spec schema_version() :: pos_integer()
```

# `structured_ingress_posture`

```elixir
@spec structured_ingress_posture() :: :structured_only
```

# `versioning_rule`

```elixir
@spec versioning_rule() :: atom()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
