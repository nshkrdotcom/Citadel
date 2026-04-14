# `Citadel.PersistedSessionEnvelope`

Versioned durable session continuity envelope.

# `t`

```elixir
@type t() :: %Citadel.PersistedSessionEnvelope{
  active_authority_decision: Citadel.AuthorityDecision.t() | nil,
  active_plan: Citadel.Plan.t() | nil,
  boundary_ref: String.t() | nil,
  continuity_revision: non_neg_integer(),
  extensions: map(),
  external_refs: map(),
  last_active_at: DateTime.t() | nil,
  last_rejection: Citadel.DecisionRejection.t() | nil,
  lifecycle_status: Citadel.SessionState.lifecycle_status(),
  outbox_entry_ids: [String.t()],
  owner_incarnation: pos_integer(),
  project_binding: Citadel.ProjectBinding.t() | nil,
  recent_signal_hashes: [String.t()],
  schema_version: pos_integer(),
  scope_ref: Citadel.ScopeRef.t() | nil,
  session_id: String.t(),
  signal_cursor: String.t() | nil
}
```

# `dump`

# `new!`

# `schema_version`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
