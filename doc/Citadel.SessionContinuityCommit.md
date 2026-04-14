# `Citadel.SessionContinuityCommit`

Single atomic continuity-write command crossing the `SessionDirectory` seam.

# `t`

```elixir
@type t() :: %Citadel.SessionContinuityCommit{
  expected_continuity_revision: non_neg_integer(),
  expected_owner_incarnation: pos_integer(),
  extensions: map(),
  persisted_blob: Citadel.PersistedSessionBlob.t(),
  session_id: String.t()
}
```

# `dump`

# `new!`

# `owner_transition`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
