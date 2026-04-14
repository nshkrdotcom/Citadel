# `Citadel.CredentialHandleRef.V1`

Lower credential-handle carrier owned below the Citadel invoke seam.

# `t`

```elixir
@type t() :: %Citadel.CredentialHandleRef.V1{
  contract_version: String.t(),
  credential_handle_id: String.t(),
  expires_at: DateTime.t() | nil,
  extensions: map(),
  handle_kind: String.t(),
  handle_ref: String.t()
}
```

# `contract_version`

# `dump`

# `new!`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
