# `Citadel.KernelContext`

Canonical pre-planning context assembled from structured ingress and policy selection.

# `t`

```elixir
@type t() :: %Citadel.KernelContext{
  actor_id: String.t(),
  approval_profile: String.t(),
  boundary_class: String.t(),
  decision_snapshot: Citadel.DecisionSnapshot.t() | nil,
  egress_profile: String.t(),
  existing_boundary_ref: String.t() | nil,
  extensions: map(),
  external_refs: map(),
  policy_epoch: non_neg_integer(),
  policy_version: String.t(),
  project_binding: Citadel.ProjectBinding.t() | nil,
  request_id: String.t(),
  resource_profile: String.t(),
  scope_ref: Citadel.ScopeRef.t(),
  selected_service: Citadel.ServiceDescriptor.t() | nil,
  selected_target: Citadel.TargetResolution.t() | nil,
  session_id: String.t(),
  signal_cursor: String.t() | nil,
  tenant_id: String.t(),
  topology_epoch: non_neg_integer(),
  trace_id: String.t(),
  trust_profile: String.t(),
  workspace_profile: String.t()
}
```

# `dump`

# `new!`

# `schema`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
