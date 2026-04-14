# `Citadel.ProcessExecutionIntent.V1`

Initial provisional process lower intent packet.

# `t`

```elixir
@type t() :: %Citadel.ProcessExecutionIntent.V1{
  args: [String.t()],
  command: String.t(),
  contract_version: String.t(),
  environment: map(),
  extensions: map(),
  stdin: term(),
  working_directory: String.t() | nil
}
```

# `contract_version`

# `dump`

# `new!`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
