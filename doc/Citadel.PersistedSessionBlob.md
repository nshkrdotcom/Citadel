# `Citadel.PersistedSessionBlob`

Single durable continuity write unit keyed by session id.

# `t`

```elixir
@type t() :: %Citadel.PersistedSessionBlob{
  envelope: Citadel.PersistedSessionEnvelope.t(),
  extensions: map(),
  outbox_entries: %{required(String.t()) =&gt; Citadel.ActionOutboxEntry.t()},
  schema_version: pos_integer(),
  session_id: String.t()
}
```

# `dump`

# `new!`

# `restore_session_outbox!`

# `schema_version`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
