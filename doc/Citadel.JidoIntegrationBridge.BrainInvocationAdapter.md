# `Citadel.JidoIntegrationBridge.BrainInvocationAdapter`

Pure projection from Citadel's execution-intent handoff into the durable
`Jido.Integration.V2.BrainInvocation` packet.

# `project!`

```elixir
@spec project!(Citadel.ExecutionIntentEnvelope.V2.t()) ::
  Jido.Integration.V2.BrainInvocation.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
