# `Citadel.HostIngress`

Public structured host-ingress seam above Citadel's runtime and lower bridge.

# `submission_result`

```elixir
@type submission_result() ::
  {:accepted, Citadel.HostIngress.Accepted.t()}
  | {:rejected, Citadel.DecisionRejection.t()}
  | {:error, term()}
```

# `t`

```elixir
@type t() :: %Citadel.HostIngress{
  clock: module(),
  lookup_session: (String.t() -&gt; {:ok, pid()} | {:error, term()}),
  policy_packs: [map()],
  session_directory: GenServer.server()
}
```

# `manifest`

```elixir
@spec manifest() :: map()
```

# `new!`

```elixir
@spec new!(keyword()) :: t()
```

# `submit_envelope`

```elixir
@spec submit_envelope(
  t(),
  Citadel.IntentEnvelope.t() | map() | keyword(),
  Citadel.HostIngress.RequestContext.t() | map() | keyword(),
  keyword()
) :: submission_result()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
