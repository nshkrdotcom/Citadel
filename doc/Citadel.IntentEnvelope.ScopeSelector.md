# `Citadel.IntentEnvelope.ScopeSelector`

Structured scope selector carried by `Citadel.IntentEnvelope`.

# `t`

```elixir
@type t() :: %Citadel.IntentEnvelope.ScopeSelector{
  environment: String.t() | nil,
  extensions: map(),
  preference: :required | :preferred,
  scope_id: String.t() | nil,
  scope_kind: String.t(),
  workspace_root: String.t() | nil
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
