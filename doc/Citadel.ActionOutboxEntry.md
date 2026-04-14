# `Citadel.ActionOutboxEntry`

Replay-safe persisted local action envelope.

# `ordering_mode`

```elixir
@type ordering_mode() :: :strict | :relaxed
```

# `replay_status`

```elixir
@type replay_status() ::
  :pending
  | :dispatched
  | :submission_accepted
  | :completed
  | :dead_letter
  | :superseded
```

# `staleness_mode`

```elixir
@type staleness_mode() :: :requires_check | :stale_exempt
```

# `t`

```elixir
@type t() :: %Citadel.ActionOutboxEntry{
  action: Citadel.LocalAction.t(),
  attempt_count: non_neg_integer(),
  backoff_policy: Citadel.BackoffPolicy.t(),
  causal_group_id: String.t(),
  dead_letter_reason: String.t() | nil,
  durable_receipt_ref: String.t() | nil,
  entry_id: String.t(),
  extensions: map(),
  inserted_at: DateTime.t(),
  last_error_code: String.t() | nil,
  max_attempts: pos_integer(),
  next_attempt_at: DateTime.t() | nil,
  ordering_mode: ordering_mode(),
  replay_status: replay_status(),
  schema_version: pos_integer(),
  staleness_mode: staleness_mode(),
  staleness_requirements: Citadel.StalenessRequirements.t() | nil,
  submission_key: String.t() | nil,
  submission_receipt_ref: String.t() | nil,
  submission_rejection: map() | nil
}
```

# `allowed_ordering_modes`

# `allowed_replay_status`

# `allowed_staleness_modes`

# `dump`

# `new!`

# `replayable?`

# `schema`

# `schema_version`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
