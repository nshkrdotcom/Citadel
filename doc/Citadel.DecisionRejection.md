# `Citadel.DecisionRejection`

Explicit pure-core rejection result for valid but unplannable or disallowed work.

# `publication_requirement`

```elixir
@type publication_requirement() ::
  :host_only | :review_projection | :derived_state_attachment
```

# `retryability`

```elixir
@type retryability() ::
  :terminal
  | :after_input_change
  | :after_runtime_change
  | :after_governance_change
```

# `t`

```elixir
@type t() :: %Citadel.DecisionRejection{
  extensions: map(),
  publication_requirement: publication_requirement(),
  reason_code: String.t(),
  rejection_id: String.t(),
  retryability: retryability(),
  stage: atom(),
  summary: String.t()
}
```

# `allowed_publication_requirements`

# `allowed_retryability`

# `classification_posture`

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
