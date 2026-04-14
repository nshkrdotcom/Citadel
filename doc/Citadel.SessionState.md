# `Citadel.SessionState`

Live mutable session state reconstructed from persisted continuity plus local visibility.

# `lifecycle_status`

```elixir
@type lifecycle_status() ::
  :active
  | :idle
  | :completed
  | :abandoned
  | :reclaiming
  | :evicted
  | :resume_pending
  | :resume_failed
  | :blocked
  | :quarantined
```

# `t`

```elixir
@type t() :: %Citadel.SessionState{
  active_authority_decision: Citadel.AuthorityDecision.t() | nil,
  active_plan: Citadel.Plan.t() | nil,
  boundary_lease_view: Citadel.BoundaryLeaseView.t() | nil,
  continuity_revision: non_neg_integer(),
  extensions: map(),
  external_refs: map(),
  last_active_at: DateTime.t() | nil,
  last_rejection: Citadel.DecisionRejection.t() | nil,
  lifecycle_status: lifecycle_status(),
  outbox: Citadel.SessionOutbox.t(),
  owner_incarnation: pos_integer(),
  project_binding: Citadel.ProjectBinding.t() | nil,
  recent_signal_hashes: [String.t()],
  scope_ref: Citadel.ScopeRef.t() | nil,
  session_id: String.t(),
  signal_cursor: String.t() | nil,
  visible_services: [Citadel.ServiceDescriptor.t()]
}
```

# `allowed_lifecycle_statuses`

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
