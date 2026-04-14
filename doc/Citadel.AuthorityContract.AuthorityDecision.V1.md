# `Citadel.AuthorityContract.AuthorityDecision.V1`

Frozen `AuthorityDecision.v1` Brain authority packet.

This module owns the field inventory and extension posture for the shared
packet. Incompatible field or semantic changes require an explicit successor
packet rather than mutation in place.

# `t`

```elixir
@type t() :: %Citadel.AuthorityContract.AuthorityDecision.V1{
  approval_profile: String.t(),
  boundary_class: String.t(),
  contract_version: String.t(),
  decision_hash: String.t(),
  decision_id: String.t(),
  egress_profile: String.t(),
  extensions: %{
    required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
  },
  policy_version: String.t(),
  request_id: String.t(),
  resource_profile: String.t(),
  tenant_id: String.t(),
  trust_profile: String.t(),
  workspace_profile: String.t()
}
```

# `contract_version`

```elixir
@spec contract_version() :: String.t()
```

# `dump`

```elixir
@spec dump(t()) :: map()
```

# `extensions_namespaces`

```elixir
@spec extensions_namespaces() :: [String.t()]
```

# `hash_payload`

```elixir
@spec hash_payload(t()) :: map()
```

# `new`

```elixir
@spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
```

# `new!`

```elixir
@spec new!(t() | map() | keyword()) :: t()
```

# `packet_name`

```elixir
@spec packet_name() :: String.t()
```

# `required_fields`

```elixir
@spec required_fields() :: [atom()]
```

# `schema`

```elixir
@spec schema() :: keyword()
```

# `versioning_rule`

```elixir
@spec versioning_rule() :: atom()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
