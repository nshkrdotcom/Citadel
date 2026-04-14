# `Citadel.InvocationBridge`

Explicit invocation bridge that stops at `Citadel.InvocationRequest.V2` and
projects the lower `ExecutionIntentEnvelope.V2` handoff locally.

# `t`

```elixir
@type t() :: %Citadel.InvocationBridge{
  circuit_policy: Citadel.BridgeCircuitPolicy.t(),
  downstream: module(),
  execution_intent_adapter: module(),
  state_ref: Citadel.BridgeState.state_ref(),
  supported_invocation_request_schema_versions: [pos_integer(), ...]
}
```

# `default_circuit_policy`

```elixir
@spec default_circuit_policy() :: Citadel.BridgeCircuitPolicy.t()
```

# `ensure_supported_invocation_request_schema_version!`

```elixir
@spec ensure_supported_invocation_request_schema_version!(integer()) :: integer()
```

# `manifest`

```elixir
@spec manifest() :: map()
```

# `new!`

```elixir
@spec new!(keyword()) :: t()
```

# `shared_contract_strategy`

```elixir
@spec shared_contract_strategy() :: :citadel_invocation_request_entrypoint
```

# `submit`

```elixir
@spec submit(
  t(),
  Citadel.InvocationRequest.V2.t(),
  Citadel.ActionOutboxEntry.t()
) ::
  {:accepted, Jido.Integration.V2.SubmissionAcceptance.t(), t()}
  | {:rejected, Jido.Integration.V2.SubmissionRejection.t(), t()}
  | {:error, atom(), t()}
```

# `submit_invocation`

```elixir
@spec submit_invocation(
  t(),
  Citadel.InvocationRequest.V2.t(),
  Citadel.ActionOutboxEntry.t()
) ::
  {:accepted, Jido.Integration.V2.SubmissionAcceptance.t(), t()}
  | {:rejected, Jido.Integration.V2.SubmissionRejection.t(), t()}
  | {:error, atom(), t()}
```

# `supported_invocation_request_schema_versions`

```elixir
@spec supported_invocation_request_schema_versions() :: [pos_integer(), ...]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
