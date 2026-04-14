# `Citadel.HostIngress.InvocationPayload`

Canonical outbox payload codec for `submit_invocation` host-ingress entries.

# `action_kind`

```elixir
@spec action_kind() :: String.t()
```

# `decode!`

```elixir
@spec decode!(map() | keyword()) :: Citadel.InvocationRequest.V2.t()
```

# `encode!`

```elixir
@spec encode!(Citadel.InvocationRequest.V2.t()) :: map()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
