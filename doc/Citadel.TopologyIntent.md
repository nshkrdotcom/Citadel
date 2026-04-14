# `Citadel.TopologyIntent`

Frozen `TopologyIntent` carrier shape owned by Citadel.

# `t`

```elixir
@type t() :: %Citadel.TopologyIntent{
  coordination_mode: String.t(),
  extensions: %{
    required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
  },
  routing_hints: %{
    required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
  },
  session_mode: String.t(),
  topology_epoch: non_neg_integer(),
  topology_intent_id: String.t()
}
```

# `allowed_coordination_modes`

```elixir
@spec allowed_coordination_modes() :: [String.t()]
```

# `allowed_session_modes`

```elixir
@spec allowed_session_modes() :: [String.t()]
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
