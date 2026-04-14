# `Citadel.Ports.IntentResolver`

Optional host-facing structured ingress resolver above the kernel.

# `resolve_intent`

```elixir
@callback resolve_intent(term()) :: {:ok, term()} | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
