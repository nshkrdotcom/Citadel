# `Citadel.Ports.Trace`

Frozen minimum trace publication seam.

# `publish_trace`

```elixir
@callback publish_trace(Citadel.TraceEnvelope.t()) :: :ok | {:error, atom()}
```

# `publish_traces`
*optional* 

```elixir
@callback publish_traces([Citadel.TraceEnvelope.t()]) :: :ok | {:error, atom()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
