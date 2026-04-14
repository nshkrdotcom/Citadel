# `Citadel.Runtime.KernelSnapshot`

Single serialized writer for aggregate `DecisionSnapshot` publication.

Hot-path readers use the read surface published by this owner rather than
issuing synchronous mailbox reads on every decision pass.

# `state`

```elixir
@type state() :: %{
  clock: module(),
  read_surface_key: term(),
  snapshot: Citadel.DecisionSnapshot.t()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `current_snapshot`

# `publish_epoch_update`

# `read_surface_key`

# `snapshot`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
