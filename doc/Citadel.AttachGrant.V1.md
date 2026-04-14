# `Citadel.AttachGrant.V1`

Durable lower attach-grant fact normalized by `boundary_bridge`.

# `t`

```elixir
@type t() :: %Citadel.AttachGrant.V1{
  attach_grant_id: String.t(),
  boundary_ref: String.t(),
  boundary_session_id: String.t(),
  contract_version: String.t(),
  credential_handle_refs: [Citadel.CredentialHandleRef.V1.t()],
  expires_at: DateTime.t() | nil,
  extensions: map(),
  granted_at: DateTime.t(),
  session_id: String.t()
}
```

# `contract_version`

# `dump`

# `new!`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
