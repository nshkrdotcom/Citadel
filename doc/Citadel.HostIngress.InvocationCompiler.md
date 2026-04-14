# `Citadel.HostIngress.InvocationCompiler`

Pure compiler from structured host ingress into durable Citadel invocation work.

# `compiled`

```elixir
@type compiled() :: %{
  selection: Citadel.PolicyPacks.Selection.t(),
  scope_ref: Citadel.ScopeRef.t(),
  invocation_request: Citadel.InvocationRequest.V2.t(),
  outbox_entry: Citadel.ActionOutboxEntry.t(),
  entry_id: String.t()
}
```

# `compile`

```elixir
@spec compile(
  Citadel.IntentEnvelope.t() | map() | keyword(),
  Citadel.HostIngress.RequestContext.t() | map() | keyword(),
  [Citadel.PolicyPacks.Selection.t() | map()],
  keyword()
) ::
  {:ok, compiled()}
  | {:rejected, Citadel.DecisionRejection.t()}
  | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
