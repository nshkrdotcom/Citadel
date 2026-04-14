# `Citadel.InvocationRequest`

Frozen Citadel-owned invoke seam handed to `invocation_bridge`.

Wave 2 freezes carrier shape and ownership here. Wave 3 may tighten value
mappings feeding `boundary_intent` and `topology_intent`, but incompatible
carrier changes require an explicit `schema_version` step.

# `attrs`

```elixir
@type attrs() :: %{
  schema_version: pos_integer(),
  invocation_request_id: String.t(),
  request_id: String.t(),
  session_id: String.t(),
  tenant_id: String.t(),
  trace_id: String.t(),
  actor_id: String.t(),
  target_id: String.t(),
  target_kind: String.t(),
  selected_step_id: String.t(),
  allowed_operations: [String.t(), ...],
  authority_packet: Citadel.AuthorityContract.AuthorityDecision.V1.t(),
  boundary_intent: Citadel.BoundaryIntent.t(),
  topology_intent: Citadel.TopologyIntent.t(),
  extensions: %{
    required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
  }
}
```

# `field_key`

```elixir
@type field_key() ::
  :schema_version
  | :invocation_request_id
  | :request_id
  | :session_id
  | :tenant_id
  | :trace_id
  | :actor_id
  | :target_id
  | :target_kind
  | :selected_step_id
  | :allowed_operations
  | :authority_packet
  | :boundary_intent
  | :topology_intent
  | :extensions
```

# `input`

```elixir
@type input() :: t() | attrs() | [{field_key(), term()}]
```

# `t`

```elixir
@type t() :: %Citadel.InvocationRequest{
  actor_id: String.t(),
  allowed_operations: [String.t(), ...],
  authority_packet: Citadel.AuthorityContract.AuthorityDecision.V1.t(),
  boundary_intent: Citadel.BoundaryIntent.t(),
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

# `new`

```elixir
@spec new(input()) :: {:ok, t()} | {:error, Exception.t()}
```

# `new!`

```elixir
@spec new!(input()) :: t()
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
