# `Citadel.HostIngress.RequestContext`

Typed request context for the public structured host-ingress seam.

# `attrs`

```elixir
@type attrs() :: keyword() | %{optional(atom() | String.t()) =&gt; term()}
```

# `t`

```elixir
@type t() :: %Citadel.HostIngress.RequestContext{
  actor_id: String.t(),
  environment: String.t() | nil,
  host_request_id: String.t() | nil,
  idempotency_key: String.t() | nil,
  metadata_keys: [String.t()],
  policy_epoch: non_neg_integer(),
  request_id: String.t(),
  session_id: String.t(),
  tenant_id: String.t(),
  trace_id: String.t(),
  trace_origin: String.t() | nil
}
```

# `dump`

```elixir
@spec dump(t()) :: map()
```

# `new!`

```elixir
@spec new!(t()) :: t()
@spec new!(attrs()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
