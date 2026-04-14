# `Citadel.ProjectBinding`

Durable host-local binding between a session and project/workspace.

# `t`

```elixir
@type t() :: %Citadel.ProjectBinding{
  binding_epoch: non_neg_integer(),
  binding_id: String.t(),
  extensions: map(),
  project_id: String.t(),
  session_id: String.t(),
  workspace_root: String.t()
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
