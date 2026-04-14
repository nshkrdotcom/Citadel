# `Citadel.ExecutionIntentEnvelope.V2`

Successor lower execution handoff with typed execution-governance carriage.

# `execution_intent_t`

```elixir
@type execution_intent_t() ::
  Citadel.HttpExecutionIntent.V1.t()
  | Citadel.ProcessExecutionIntent.V1.t()
  | Citadel.JsonRpcExecutionIntent.V1.t()
```

# `t`

```elixir
@type t() :: %Citadel.ExecutionIntentEnvelope.V2{
  actor_id: String.t(),
  allowed_operations: [String.t()],
  authority_packet: Citadel.AuthorityContract.AuthorityDecision.V1.t(),
  boundary_intent: Citadel.BoundaryIntent.t(),
  causal_group_id: String.t(),
  contract_version: String.t(),
  entry_id: String.t(),
  execution_governance: Citadel.ExecutionGovernance.V1.t(),
  execution_intent: execution_intent_t(),
  execution_intent_family: String.t(),
  extensions: map(),
  intent_envelope_id: String.t(),
  invocation_request_id: String.t(),
  invocation_schema_version: pos_integer(),
  request_id: String.t(),
  session_id: String.t(),
  target_id: String.t(),
  target_kind: String.t(),
  tenant_id: String.t(),
  topology_intent: Citadel.TopologyIntent.t(),
  trace_id: String.t()
}
```

# `contract_version`

# `dump`

# `intent_families`

# `new!`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
