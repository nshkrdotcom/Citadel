# `Citadel.TraceEnvelope`

Canonical Citadel-owned trace publication value.

# `record_kind`

```elixir
@type record_kind() :: :event | :span
```

# `t`

```elixir
@type t() :: %Citadel.TraceEnvelope{
  attributes: map(),
  boundary_ref: String.t() | nil,
  decision_id: String.t() | nil,
  extensions: map(),
  family: String.t(),
  finished_at: DateTime.t() | nil,
  name: String.t(),
  occurred_at: DateTime.t() | nil,
  outbox_entry_id: String.t() | nil,
  parent_span_id: String.t() | nil,
  phase: String.t(),
  record_kind: record_kind(),
  request_id: String.t() | nil,
  session_id: String.t() | nil,
  signal_id: String.t() | nil,
  snapshot_seq: non_neg_integer() | nil,
  span_id: String.t() | nil,
  started_at: DateTime.t() | nil,
  status: String.t() | nil,
  tenant_id: String.t() | nil,
  trace_envelope_id: String.t(),
  trace_id: String.t()
}
```

# `dump`

# `family_classification`

# `new`

# `new!`

# `protected_error_family?`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
