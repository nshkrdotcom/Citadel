defmodule Citadel.ObservabilityContract.Trace do
  @moduledoc """
  Frozen minimum trace vocabulary, correlation keys, and failure codes.
  """

  @record_kinds [:event, :span]
  @required_event_families [
    "decision_snapshot_captured",
    "authority_decision_compiled",
    "invocation_projected",
    "invocation_submitted",
    "signal_normalized",
    "signal_reduced",
    "outbox_entry_persisted",
    "outbox_entry_replayed",
    "outbox_entry_dispatched",
    "session_attached",
    "session_resumed",
    "session_crash_recovery_triggered",
    "redecision_triggered",
    "review_projection_published",
    "derived_state_attachment_published",
    "boundary_lease_stale",
    "boundary_lease_expired"
  ]
  @protected_error_families [
    "decision_rejected",
    "invocation_failed",
    "projection_failed",
    "outbox_entry_dead_lettered",
    "session_blocked",
    "session_quarantined",
    "session_crash_recovery_triggered",
    "stale_dispatch_blocked",
    "boundary_lease_stale",
    "boundary_lease_expired"
  ]
  @required_correlation_keys [
    :trace_id,
    :tenant_id,
    :session_id,
    :request_id,
    :decision_id,
    :snapshot_seq,
    :signal_id,
    :outbox_entry_id,
    :boundary_ref
  ]
  @failure_reason_codes [
    :unavailable,
    :timeout,
    :rate_limited,
    :invalid_envelope,
    :backend_rejected,
    :circuit_open,
    :unknown
  ]
  @canonical_event_names %{
    "decision_snapshot_captured" => "citadel.decision.snapshot_captured",
    "authority_decision_compiled" => "citadel.decision.authority_compiled",
    "invocation_projected" => "citadel.invocation.projected",
    "invocation_submitted" => "citadel.invocation.submitted",
    "signal_normalized" => "citadel.signal.normalized",
    "signal_reduced" => "citadel.signal.reduced",
    "outbox_entry_persisted" => "citadel.outbox.entry_persisted",
    "outbox_entry_replayed" => "citadel.outbox.entry_replayed",
    "outbox_entry_dispatched" => "citadel.outbox.entry_dispatched",
    "session_attached" => "citadel.session.attached",
    "session_resumed" => "citadel.session.resumed",
    "session_crash_recovery_triggered" => "citadel.session.crash_recovery_triggered",
    "redecision_triggered" => "citadel.decision.redecision_triggered",
    "review_projection_published" => "citadel.projection.review_published",
    "derived_state_attachment_published" => "citadel.projection.derived_state_attachment_published",
    "boundary_lease_stale" => "citadel.boundary.lease_stale",
    "boundary_lease_expired" => "citadel.boundary.lease_expired",
    "decision_rejected" => "citadel.decision.rejected",
    "invocation_failed" => "citadel.invocation.failed",
    "projection_failed" => "citadel.projection.failed",
    "outbox_entry_dead_lettered" => "citadel.outbox.entry_dead_lettered",
    "session_blocked" => "citadel.session.blocked",
    "session_quarantined" => "citadel.session.quarantined",
    "stale_dispatch_blocked" => "citadel.outbox.stale_dispatch_blocked"
  }

  @spec record_kinds() :: [atom(), ...]
  def record_kinds, do: @record_kinds

  @spec required_event_families() :: [String.t(), ...]
  def required_event_families, do: @required_event_families

  @spec protected_error_families() :: [String.t(), ...]
  def protected_error_families, do: @protected_error_families

  @spec required_correlation_keys() :: [atom(), ...]
  def required_correlation_keys, do: @required_correlation_keys

  @spec failure_reason_codes() :: [atom(), ...]
  def failure_reason_codes, do: @failure_reason_codes

  @spec canonical_event_names() :: map()
  def canonical_event_names, do: @canonical_event_names

  @spec canonical_event_name!(String.t()) :: String.t()
  def canonical_event_name!(family) do
    case Map.fetch(@canonical_event_names, family) do
      {:ok, name} ->
        name

      :error ->
        raise ArgumentError, "unsupported Citadel trace family: #{inspect(family)}"
    end
  end

  @spec family_classification(String.t()) :: :protected_error | :default
  def family_classification(family) when family in @protected_error_families, do: :protected_error
  def family_classification(_family), do: :default

  @spec protected_error_family?(String.t()) :: boolean()
  def protected_error_family?(family), do: family_classification(family) == :protected_error

  @spec required_event_family?(String.t()) :: boolean()
  def required_event_family?(family), do: family in @required_event_families

  @spec known_family?(String.t()) :: boolean()
  def known_family?(family), do: Map.has_key?(@canonical_event_names, family)
end
