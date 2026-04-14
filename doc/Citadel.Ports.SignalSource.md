# `Citadel.Ports.SignalSource`

Normalizes runtime signals into `Citadel.RuntimeObservation`.

# `raw_signal`

```elixir
@type raw_signal() :: %{optional(atom() | String.t()) =&gt; term()}
```

# `normalize_signal`

```elixir
@callback normalize_signal(raw_signal()) ::
  {:ok, Citadel.RuntimeObservation.t()} | {:error, atom()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
