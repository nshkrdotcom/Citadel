# `Citadel.BoundaryIntent`

Frozen `BoundaryIntent` carrier shape owned by Citadel.

# `t`

```elixir
@type t() :: %Citadel.BoundaryIntent{
  boundary_class: String.t(),
  extensions: %{
    required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
  },
  requested_attach_mode: String.t(),
  requested_ttl_ms: non_neg_integer(),
  resource_profile: String.t(),
  trust_profile: String.t(),
  workspace_profile: String.t()
}
```

# `allowed_attach_modes`

```elixir
@spec allowed_attach_modes() :: [String.t()]
```

# `dump`

```elixir
@spec dump(t()) :: map()
```

# `new`

```elixir
@spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
```

# `new!`

```elixir
@spec new!(t() | map() | keyword()) :: t()
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
