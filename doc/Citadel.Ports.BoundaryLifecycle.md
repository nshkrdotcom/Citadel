# `Citadel.Ports.BoundaryLifecycle`

Projects boundary intent and normalizes boundary lifecycle facts.

# `attach_grant_source`

```elixir
@type attach_grant_source() ::
  Citadel.AttachGrant.V1.t()
  | %{
      :contract_version =&gt; String.t(),
      :attach_grant_id =&gt; String.t(),
      :boundary_session_id =&gt; String.t(),
      :boundary_ref =&gt; String.t(),
      :session_id =&gt; String.t(),
      :granted_at =&gt; DateTime.t() | String.t(),
      optional(:expires_at) =&gt; DateTime.t() | String.t() | nil,
      optional(:credential_handle_refs) =&gt; [term()],
      optional(:extensions) =&gt; %{
        optional(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
      }
    }
```

# `boundary_intent_metadata`

```elixir
@type boundary_intent_metadata() :: %{
  :session_id =&gt; String.t(),
  :tenant_id =&gt; String.t(),
  :target_id =&gt; String.t(),
  optional(:authority_packet) =&gt;
    Citadel.AuthorityContract.AuthorityDecision.V1.t(),
  optional(:execution_governance) =&gt; Citadel.ExecutionGovernance.V1.t(),
  optional(:downstream_scope) =&gt; String.t(),
  optional(:extensions) =&gt; %{
    optional(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
  }
}
```

# `boundary_lease_source`

```elixir
@type boundary_lease_source() ::
  Citadel.BoundaryLeaseView.t()
  | %{
      :boundary_ref =&gt; String.t(),
      optional(:last_heartbeat_at) =&gt; DateTime.t() | String.t() | nil,
      optional(:expires_at) =&gt; DateTime.t() | String.t() | nil,
      :staleness_status =&gt; Citadel.BoundaryLeaseView.staleness_status(),
      :lease_epoch =&gt; non_neg_integer(),
      optional(:extensions) =&gt; %{
        optional(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
      }
    }
```

# `boundary_session_source`

```elixir
@type boundary_session_source() ::
  Citadel.BoundarySessionDescriptor.V1.t()
  | %{
      :contract_version =&gt; String.t(),
      :boundary_session_id =&gt; String.t(),
      :boundary_ref =&gt; String.t(),
      :session_id =&gt; String.t(),
      :tenant_id =&gt; String.t(),
      :target_id =&gt; String.t(),
      :boundary_class =&gt; String.t(),
      :status =&gt; String.t(),
      :attach_mode =&gt; String.t(),
      optional(:lease_expires_at) =&gt; DateTime.t() | String.t() | nil,
      optional(:last_heartbeat_at) =&gt; DateTime.t() | String.t() | nil,
      optional(:extensions) =&gt; %{
        optional(String.t()) =&gt; Citadel.ContractCore.CanonicalJson.value()
      }
    }
```

# `lifecycle_submission_result`

```elixir
@type lifecycle_submission_result() :: {:ok, String.t()} | {:error, atom()}
```

# `normalize_attach_grant`

```elixir
@callback normalize_attach_grant(attach_grant_source()) ::
  {:ok, Citadel.AttachGrant.V1.t()} | {:error, atom()}
```

# `normalize_boundary_lease`

```elixir
@callback normalize_boundary_lease(boundary_lease_source()) ::
  {:ok, Citadel.BoundaryLeaseView.t()} | {:error, atom()}
```

# `normalize_boundary_session`

```elixir
@callback normalize_boundary_session(boundary_session_source()) ::
  {:ok, Citadel.BoundarySessionDescriptor.V1.t()} | {:error, atom()}
```

# `submit_boundary_intent`

```elixir
@callback submit_boundary_intent(Citadel.BoundaryIntent.t(), boundary_intent_metadata()) ::
  lifecycle_submission_result()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
