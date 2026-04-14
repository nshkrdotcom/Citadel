# `Citadel.Runtime.BoundaryLeaseTracker`

Host-local boundary liveness and targeted resume-classification owner.

# `bootstrap_result`

```elixir
@type bootstrap_result() ::
  {:ok, Citadel.BoundaryLeaseView.t()}
  | {:error,
     :not_ready | :resume_pending | :missing | :expired | :circuit_open | atom()}
```

# `boundary_epoch`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `classify_for_resume`

# `current_view`

# `record_boundary_view`

# `set_circuit_open`

# `set_warm`

# `start_link`

# `warm?`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
