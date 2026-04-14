# `Citadel.HostIngress.Accepted`

Typed successful result for the public host-ingress seam.

# `attrs`

```elixir
@type attrs() :: keyword() | %{optional(atom() | String.t()) =&gt; term()}
```

# `t`

```elixir
@type t() :: %Citadel.HostIngress.Accepted{
  continuity_revision: non_neg_integer() | nil,
  entry_id: String.t() | nil,
  ingress_path: atom() | nil,
  lifecycle_event: atom() | nil,
  metadata: map(),
  request_id: String.t(),
  schema_version: pos_integer(),
  session_id: String.t() | nil,
  trace_id: String.t()
}
```

# `new!`

```elixir
@spec new!(attrs()) :: t()
```

# `schema_version`

```elixir
@spec schema_version() :: pos_integer()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
