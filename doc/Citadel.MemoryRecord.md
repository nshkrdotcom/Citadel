# `Citadel.MemoryRecord`

Host-local advisory memory item surfaced through `Citadel.Ports.Memory`.

# `t`

```elixir
@type t() :: %Citadel.MemoryRecord{
  confidence: float(),
  evidence_links: [String.t()],
  expires_at: DateTime.t() | nil,
  kind: String.t(),
  memory_id: String.t(),
  metadata: map(),
  scope_ref: Citadel.ScopeRef.t(),
  session_id: String.t() | nil,
  subject_links: [String.t()],
  summary: String.t()
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
