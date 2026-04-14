# `Citadel.SessionOutbox`

Live in-memory session outbox working set with explicit one-to-one invariants.

# `t`

```elixir
@type t() :: %Citadel.SessionOutbox{
  entries_by_id: %{required(String.t()) =&gt; Citadel.ActionOutboxEntry.t()},
  entry_order: [String.t()],
  extensions: map()
}
```

# `delete_entry!`

# `dump`

# `ensure_invariant!`

# `from_entries!`

# `invariant?`

# `new!`

# `put_entry!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
