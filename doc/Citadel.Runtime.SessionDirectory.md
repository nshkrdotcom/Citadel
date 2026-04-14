# `Citadel.Runtime.SessionDirectory`

Continuity-store owner for persisted session blobs, activation policy, and
dead-letter maintenance.

# `continuity_fault`

```elixir
@type continuity_fault() ::
  :ok
  | {:error, :acknowledgement_missing}
  | {:error, :acknowledgement_ambiguous, :committed}
  | {:error, :acknowledgement_ambiguous, :not_committed}
```

# `state`

```elixir
@type state() :: %{
  clock: module(),
  kernel_snapshot: term(),
  flush_interval_ms: non_neg_integer(),
  activation_policy: Citadel.SessionActivationPolicy.t(),
  store_key: term(),
  store: map(),
  fault_injection:
    (Citadel.SessionContinuityCommit.t() -&gt; continuity_fault()) | nil,
  pending_project_binding_epoch: non_neg_integer() | nil,
  pending_updated_at: DateTime.t() | nil,
  flush_timer_ref: reference() | nil,
  activation_queue: %{
    optional(String.t()) =&gt; %{
      priority_class: String.t(),
      queued_at: DateTime.t()
    }
  }
}
```

# `batch_load_committed_cursors`

# `bulk_recover_dead_letters`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `claim_session`

# `clear_dead_letter`

# `commit_continuity`

# `configure_fault_injection`

# `enqueue_activation`

# `fetch_persisted_blob`

# `force_evict_quarantined`

# `inspect_session`

# `list_active_session_cursors`

# `next_activation_batch`

# `project_binding_epoch`

# `quarantine_session`

# `quarantined_sessions`

# `register_active_session`

# `replace_dead_letter`

# `reset!`

# `resolve_outbox_entry`

# `retry_dead_letter_with_override`

# `seed_raw_blob`

# `start_link`

# `unregister_active_session`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
