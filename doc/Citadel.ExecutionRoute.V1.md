# `Citadel.ExecutionRoute.V1`

Durable lower execution route fact.

# `t`

```elixir
@type t() :: %Citadel.ExecutionRoute.V1{
  boundary_session_id: String.t() | nil,
  contract_version: String.t(),
  downstream_scope: String.t(),
  extensions: map(),
  intent_envelope_id: String.t(),
  route_id: String.t(),
  target_locator: map(),
  transport_family: String.t()
}
```

# `contract_version`

# `dump`

# `new!`

# `transport_families`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
