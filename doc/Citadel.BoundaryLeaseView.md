# `Citadel.BoundaryLeaseView`

Host-local view of one boundary's liveness and reuse posture.

# `staleness_status`

```elixir
@type staleness_status() :: :fresh | :stale | :expired | :missing
```

# `t`

```elixir
@type t() :: %Citadel.BoundaryLeaseView{
  boundary_ref: String.t(),
  expires_at: DateTime.t() | nil,
  extensions: map(),
  last_heartbeat_at: DateTime.t() | nil,
  lease_epoch: non_neg_integer(),
  staleness_status: staleness_status()
}
```

# `allowed_statuses`

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
