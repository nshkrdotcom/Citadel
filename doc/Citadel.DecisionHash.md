# `Citadel.DecisionHash`

Canonical `decision_hash` implementation for `AuthorityDecision.v1`.

The hash is computed from the projected shared packet with `decision_hash`
removed, normalized through `Citadel.ContractCore.CanonicalJson`, encoded with
`Jcs.encode/1`, and digested with SHA-256.

# `authority_hash!`

```elixir
@spec authority_hash!(
  Citadel.AuthorityContract.AuthorityDecision.V1.t()
  | map()
  | keyword()
) ::
  String.t()
```

# `authority_hash_valid?`

```elixir
@spec authority_hash_valid?(Citadel.AuthorityContract.AuthorityDecision.V1.t()) ::
  boolean()
```

# `canonical_payload!`

```elixir
@spec canonical_payload!(Citadel.AuthorityContract.AuthorityDecision.V1.t() | map()) ::
  String.t()
```

# `put_authority_hash!`

```elixir
@spec put_authority_hash!(
  Citadel.AuthorityContract.AuthorityDecision.V1.t()
  | map()
  | keyword()
) ::
  Citadel.AuthorityContract.AuthorityDecision.V1.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
