defmodule Citadel.ObservabilityContract.Telemetry do
  @moduledoc """
  Frozen low-cardinality telemetry event names, measurements, and metadata.
  """

  @definitions %{
    decision_task_latency: %{
      event_name: [:citadel, :decision_task, :latency],
      measurements: [:duration_ms],
      metadata: [:status]
    },
    action_task_latency: %{
      event_name: [:citadel, :action_task, :latency],
      measurements: [:duration_ms],
      metadata: [:status, :action_kind]
    },
    kernel_snapshot_lag: %{
      event_name: [:citadel, :kernel_snapshot, :lag],
      measurements: [:backlog, :lag_ms],
      metadata: []
    },
    active_session_count: %{
      event_name: [:citadel, :session, :active_count],
      measurements: [:count],
      metadata: []
    },
    session_lifecycle_count: %{
      event_name: [:citadel, :session, :lifecycle_count],
      measurements: [:count],
      metadata: [:lifecycle_event]
    },
    quarantined_session_count: %{
      event_name: [:citadel, :session, :quarantined_count],
      measurements: [:count],
      metadata: []
    },
    signal_ingress_lag: %{
      event_name: [:citadel, :signal_ingress, :lag],
      measurements: [:lag_ms],
      metadata: [:source]
    },
    signal_ingress_rebuild_backlog: %{
      event_name: [:citadel, :signal_ingress, :rebuild_backlog],
      measurements: [:count],
      metadata: [:priority_class]
    },
    signal_ingress_rebuild_batch_latency: %{
      event_name: [:citadel, :signal_ingress, :rebuild_batch_latency],
      measurements: [:duration_ms],
      metadata: [:priority_class]
    },
    signal_ingress_high_priority_ready_latency: %{
      event_name: [:citadel, :signal_ingress, :high_priority_ready_latency],
      measurements: [:duration_ms],
      metadata: []
    },
    signal_ingress_admission_rejection: %{
      event_name: [:citadel, :signal_ingress, :admission, :rejection],
      measurements: [:queue_depth, :tenant_scope_in_flight, :retry_after_ms],
      metadata: [:reason_code, :delivery_order_scope]
    },
    signal_ingress_delivery_overload: %{
      event_name: [:citadel, :signal_ingress, :delivery, :overload],
      measurements: [:duration_ms, :retry_after_ms],
      metadata: [:reason_code, :delivery_order_scope, :replay_action]
    },
    trace_buffer_depth: %{
      event_name: [:citadel, :trace, :buffer, :depth],
      measurements: [:depth, :protected_depth, :regular_depth],
      metadata: []
    },
    trace_publication_failure: %{
      event_name: [:citadel, :trace, :publish, :failure],
      measurements: [:count, :batch_size],
      metadata: [
        :reason_code,
        :trace_id,
        :tenant_id,
        :request_id,
        :decision_id,
        :boundary_ref,
        :trace_envelope_id,
        :family
      ]
    },
    trace_publication_drop: %{
      event_name: [:citadel, :trace, :publish, :drop],
      measurements: [:count],
      metadata: [
        :dropped_family,
        :dropped_family_classification,
        :trace_id,
        :tenant_id,
        :request_id,
        :decision_id,
        :boundary_ref,
        :trace_envelope_id
      ]
    },
    outbox_pending_backlog: %{
      event_name: [:citadel, :outbox, :pending_backlog],
      measurements: [:count],
      metadata: [:ordering_mode]
    },
    outbox_dead_letter_count: %{
      event_name: [:citadel, :outbox, :dead_letter_count],
      measurements: [:count],
      metadata: [:reason_family]
    },
    dead_letter_bulk_recovery: %{
      event_name: [:citadel, :outbox, :dead_letter_bulk_recovery],
      measurements: [:operation_count, :affected_entry_count],
      metadata: []
    },
    blocked_session_count: %{
      event_name: [:citadel, :session, :blocked_count],
      measurements: [:count],
      metadata: [:reason_family]
    },
    blocked_session_alert_count: %{
      event_name: [:citadel, :session, :blocked_alert_count],
      measurements: [:count],
      metadata: [:strict_dead_letter_family]
    },
    invocation_dispatch_backlog: %{
      event_name: [:citadel, :invocation_dispatch, :backlog],
      measurements: [:count],
      metadata: []
    },
    projection_dispatch_backlog: %{
      event_name: [:citadel, :projection_dispatch, :backlog],
      measurements: [:count],
      metadata: []
    },
    boundary_bootstrap_backlog: %{
      event_name: [:citadel, :boundary_bootstrap, :backlog],
      measurements: [:count, :coalesced_request_count],
      metadata: []
    },
    cold_boot_activation: %{
      event_name: [:citadel, :cold_boot, :activation],
      measurements: [:backlog, :latency_ms],
      metadata: [:priority_class]
    },
    bridge_circuit_open: %{
      event_name: [:citadel, :bridge, :circuit, :open],
      measurements: [:count],
      metadata: [:bridge_family, :circuit_scope_class, :boundary_ref]
    },
    policy_peek_latency: %{
      event_name: [:citadel, :policy, :peek_latency],
      measurements: [:duration_ms],
      metadata: []
    },
    decision_rejection_count: %{
      event_name: [:citadel, :decision, :rejection_count],
      measurements: [:count],
      metadata: [:reason_family]
    }
  }

  @spec definitions() :: map()
  def definitions, do: @definitions

  @spec event_name(atom()) :: [atom(), ...]
  def event_name(name), do: definition!(name).event_name

  @spec measurement_keys(atom()) :: [atom(), ...]
  def measurement_keys(name), do: definition!(name).measurements

  @spec metadata_keys(atom()) :: [atom(), ...]
  def metadata_keys(name), do: definition!(name).metadata

  @spec definition!(atom()) :: map()
  def definition!(name) do
    case Map.fetch(@definitions, name) do
      {:ok, definition} -> definition
      :error -> raise ArgumentError, "unsupported Citadel telemetry definition: #{inspect(name)}"
    end
  end
end
