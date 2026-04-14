# `Citadel.PolicyPacks`

Explicit policy-pack definitions and deterministic profile selection.

# `selection_input`

```elixir
@type selection_input() :: %{
  :tenant_id =&gt; String.t(),
  :scope_kind =&gt; String.t(),
  optional(:environment) =&gt; String.t(),
  optional(:policy_epoch) =&gt; non_neg_integer()
}
```

# `manifest`

```elixir
@spec manifest() :: map()
```

# `select_profile`

```elixir
@spec select_profile([Citadel.PolicyPacks.PolicyPack.t() | map()], map() | keyword()) ::
  {:ok, Citadel.PolicyPacks.Selection.t()} | {:error, Exception.t()}
```

# `select_profile!`

```elixir
@spec select_profile!([Citadel.PolicyPacks.PolicyPack.t() | map()], map() | keyword()) ::
  Citadel.PolicyPacks.Selection.t()
```

# `selection_inputs`

```elixir
@spec selection_inputs() :: [atom()]
```

# `stable_selection_ordering`

```elixir
@spec stable_selection_ordering() :: :priority_desc_then_pack_id_asc
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
