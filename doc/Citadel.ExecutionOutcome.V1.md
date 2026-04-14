# `Citadel.ExecutionOutcome.V1`

Raw lower execution terminal fact consumed as an outcome.

# `t`

```elixir
@type t() :: %Citadel.ExecutionOutcome.V1{
  boundary_ref: String.t() | nil,
  causal_group_id: String.t(),
  contract_version: String.t(),
  entry_id: String.t(),
  execution_outcome_id: String.t(),
  extensions: map(),
  finished_at: DateTime.t(),
  intent_envelope_id: String.t(),
  result: map(),
  route_id: String.t(),
  session_id: String.t(),
  status: String.t(),
  trace_id: String.t()
}
```

# `contract_version`

# `dump`

# `new!`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
