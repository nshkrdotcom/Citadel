defmodule Citadel.Runtime.Staleness do
  @moduledoc false

  alias Citadel.ActionOutboxEntry
  alias Citadel.DecisionSnapshot
  alias Citadel.SessionState
  alias Citadel.StalenessRequirements

  def stale?(%ActionOutboxEntry{staleness_mode: :stale_exempt}, _snapshot, _session_state),
    do: false

  def stale?(
        %ActionOutboxEntry{staleness_requirements: %StalenessRequirements{} = requirements},
        %DecisionSnapshot{} = snapshot,
        %SessionState{} = session_state
      ) do
    epoch_mismatch?(requirements.policy_epoch, snapshot.policy_epoch) or
      epoch_mismatch?(requirements.topology_epoch, snapshot.topology_epoch) or
      epoch_mismatch?(requirements.scope_catalog_epoch, snapshot.scope_catalog_epoch) or
      epoch_mismatch?(requirements.service_admission_epoch, snapshot.service_admission_epoch) or
      epoch_mismatch?(requirements.project_binding_epoch, snapshot.project_binding_epoch) or
      epoch_mismatch?(requirements.boundary_epoch, snapshot.boundary_epoch) or
      binding_mismatch?(requirements.required_binding_id, session_state) or
      boundary_mismatch?(requirements.required_boundary_ref, session_state)
  end

  def stale?(%ActionOutboxEntry{}, _snapshot, _session_state), do: true

  defp epoch_mismatch?(nil, _current_epoch), do: false
  defp epoch_mismatch?(required, current_epoch), do: required != current_epoch

  defp binding_mismatch?(nil, _session_state), do: false

  defp binding_mismatch?(_required_binding_id, %SessionState{project_binding: nil}), do: true

  defp binding_mismatch?(required_binding_id, %SessionState{project_binding: binding}) do
    binding.binding_id != required_binding_id
  end

  defp boundary_mismatch?(nil, _session_state), do: false

  defp boundary_mismatch?(_required_boundary_ref, %SessionState{boundary_lease_view: nil}),
    do: true

  defp boundary_mismatch?(required_boundary_ref, %SessionState{
         boundary_lease_view: boundary_lease_view
       }) do
    boundary_lease_view.boundary_ref != required_boundary_ref or
      boundary_lease_view.staleness_status != :fresh
  end
end
