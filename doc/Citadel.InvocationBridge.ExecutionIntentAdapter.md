# `Citadel.InvocationBridge.ExecutionIntentAdapter`

Explicit adapter that freezes the `InvocationRequest.V2 -> ExecutionIntentEnvelope.V2`
handoff without pretending the lower family already exists downstream.

# `project!`

```elixir
@spec project!(Citadel.InvocationRequest.V2.t(), Citadel.ActionOutboxEntry.t()) ::
  Citadel.ExecutionIntentEnvelope.V2.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
