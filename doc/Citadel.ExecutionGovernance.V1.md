# `Citadel.ExecutionGovernance.V1`

Frozen `ExecutionGovernance.v1` Brain-to-Spine packet.

This packet compiles the Brain-authored execution and sandbox posture into a
typed lower handoff without collapsing provider or backend details into the
Brain boundary.

# `authority_ref_t`

```elixir
@type authority_ref_t() :: %{
  required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
}
```

# `boundary_t`

```elixir
@type boundary_t() :: %{
  required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
}
```

# `operations_t`

```elixir
@type operations_t() :: %{
  required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
}
```

# `placement_t`

```elixir
@type placement_t() :: %{
  required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
}
```

# `resources_t`

```elixir
@type resources_t() :: %{
  required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
}
```

# `sandbox_t`

```elixir
@type sandbox_t() :: %{
  required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
}
```

# `t`

```elixir
@type t() :: %Citadel.ExecutionGovernance.V1{
  authority_ref: authority_ref_t(),
  boundary: boundary_t(),
  contract_version: String.t(),
  execution_governance_id: String.t(),
  extensions: %{
    required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
  },
  operations: operations_t(),
  placement: placement_t(),
  resources: resources_t(),
  sandbox: sandbox_t(),
  topology: topology_t(),
  workspace: workspace_t()
}
```

# `topology_t`

```elixir
@type topology_t() :: %{
  required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
}
```

# `workspace_t`

```elixir
@type workspace_t() :: %{
  required(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
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
