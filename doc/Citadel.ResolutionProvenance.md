# `Citadel.ResolutionProvenance`

Explicit provenance for how a structured `IntentEnvelope` was formed.

# `t`

```elixir
@type t() :: %Citadel.ResolutionProvenance{
  ambiguity_flags: [String.t()],
  confidence: float() | nil,
  extensions: map(),
  policy_version: String.t() | nil,
  prompt_version: String.t() | nil,
  raw_input_hashes: [String.t()],
  raw_input_refs: [String.t()],
  resolver_kind: String.t() | nil,
  resolver_version: String.t() | nil,
  source_kind: String.t()
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
