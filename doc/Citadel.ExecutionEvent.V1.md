# `Citadel.ExecutionEvent.V1`

Raw lower execution fact consumed as an event.

# `t`

```elixir
@type t() :: %Citadel.ExecutionEvent.V1{
  boundary_ref: String.t() | nil,
  causal_group_id: String.t(),
  contract_version: String.t(),
  entry_id: String.t(),
  event_kind: String.t(),
  execution_event_id: String.t(),
  extensions: map(),
  intent_envelope_id: String.t(),
  occurred_at: DateTime.t(),
  payload: map(),
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
