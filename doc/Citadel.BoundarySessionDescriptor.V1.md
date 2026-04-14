# `Citadel.BoundarySessionDescriptor.V1`

Durable lower boundary-session fact normalized by `boundary_bridge` and `query_bridge`.

# `t`

```elixir
@type t() :: %Citadel.BoundarySessionDescriptor.V1{
  attach_mode: String.t(),
  boundary_class: String.t(),
  boundary_ref: String.t(),
  boundary_session_id: String.t(),
  contract_version: String.t(),
  extensions: map(),
  last_heartbeat_at: DateTime.t() | nil,
  lease_expires_at: DateTime.t() | nil,
  session_id: String.t(),
  status: String.t(),
  target_id: String.t(),
  tenant_id: String.t()
}
```

# `allowed_statuses`

# `contract_version`

# `dump`

# `new!`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
