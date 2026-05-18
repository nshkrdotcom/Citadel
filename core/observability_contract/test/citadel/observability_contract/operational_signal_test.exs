defmodule Citadel.ObservabilityContract.OperationalSignalTest do
  use ExUnit.Case, async: true

  alias Citadel.ObservabilityContract

  alias Citadel.ObservabilityContract.{
    OperationalRunbook,
    OperationalSLO,
    OperationalSignal,
    OperatorSignalAdapter,
    Telemetry
  }

  @signal_names [
    :binding_lookup,
    :authority_decision,
    :credential_lease_materialization,
    :lower_invocation,
    :receipt_reduction,
    :projection_lag,
    :aitrace_export_lag,
    :live_provider_effect_status
  ]

  @slo_threshold_names [
    :revocation_bound_ms,
    :tenant_bypass_attempts,
    :trace_export_drops,
    :external_secret_resolver_failures,
    :binding_cache_stale_reads,
    :projection_lag_ms,
    :lower_provider_error_rate
  ]

  test "facade exposes operational observability ownership" do
    assert ObservabilityContract.operational_signal_module() == OperationalSignal
    assert ObservabilityContract.operational_slo_module() == OperationalSLO
    assert ObservabilityContract.operational_signal_names() == @signal_names
    assert ObservabilityContract.operational_slo_threshold_names() == @slo_threshold_names

    owns = ObservabilityContract.manifest().owns

    assert :operational_signal_v1 in owns
    assert :operational_slo_thresholds_v1 in owns
    assert :operational_runbooks_v1 in owns
    assert :operator_signal_backend_envelopes_v1 in owns
  end

  test "default operational signals cover the Phase 8 operator surfaces" do
    signals = ObservabilityContract.operational_signals()

    assert Map.keys(signals) |> Enum.sort() == Enum.sort(@signal_names)

    for name <- @signal_names do
      signal = Map.fetch!(signals, name)

      assert signal.contract_name == "Platform.OperationalSignal.v1"
      assert signal.contract_version == "1.0.0"
      assert signal.signal_name == name
      assert signal.operation_family == Atom.to_string(name)
      assert signal.release_manifest_ref == "phase8-operational-observability"
      assert signal.redaction_policy_ref == "citadel.redaction.refs_only.v1"
      assert String.contains?(signal.runbook_ref, "docs/runbooks/operational_observability.md")
      assert :ok = OperationalSignal.validate_signal(signal)

      telemetry_name = :"operational_#{name}"
      assert signal.telemetry_event == Telemetry.event_name(telemetry_name)

      definition = Telemetry.definition!(telemetry_name)
      assert Map.keys(signal.measurements) |> Enum.sort() == Enum.sort(definition.measurements)

      assert MapSet.subset?(
               MapSet.new(Map.keys(signal.metric_labels)),
               MapSet.new(definition.metadata)
             )
    end
  end

  test "backend adapter shapes operator telemetry logs metrics and traces without AITrace replay events" do
    signal = OperationalSignal.signal!(:lower_invocation)
    envelopes = ObservabilityContract.operator_signal_backend_envelopes(signal)

    assert envelopes.telemetry == OperatorSignalAdapter.telemetry_envelope(signal)
    assert envelopes.telemetry.backend == :telemetry
    assert envelopes.telemetry.event_name == [:citadel, :operational, :lower_invocation]
    assert envelopes.telemetry.measurements.retry_count == 0
    assert envelopes.telemetry.metadata.operation_family == "lower_invocation"

    assert envelopes.metric.backend == :metric
    assert envelopes.metric.labels == signal.metric_labels
    assert envelopes.log.backend == :log
    assert envelopes.log.fields == signal.log_fields
    assert envelopes.trace.backend == :trace
    assert envelopes.trace.attributes == signal.trace_attributes

    refute Map.has_key?(envelopes, :audit)
    refute Map.has_key?(envelopes, :replay)
  end

  test "operational signals reject raw payload and secret field names" do
    base =
      OperationalSignal.signal!(:credential_lease_materialization) |> OperationalSignal.dump()

    assert {:error, %ArgumentError{message: message}} =
             base
             |> put_in([:trace_attributes, :secret], "not-redacted")
             |> OperationalSignal.new()

    assert String.contains?(message, "trace_attributes")

    assert {:error, %ArgumentError{message: message}} =
             base
             |> put_in([:log_fields, :provider_response_body], "not-redacted")
             |> OperationalSignal.new()

    assert String.contains?(message, "log_fields")
  end

  test "operational metric metadata stays low-cardinality" do
    base = OperationalSignal.signal!(:binding_lookup) |> OperationalSignal.dump()

    assert {:error, %ArgumentError{message: message}} =
             base
             |> put_in([:metric_labels, :trace_id], "trace-123")
             |> OperationalSignal.new()

    assert String.contains?(message, "metric_labels")
  end

  test "SLO thresholds cover operational failure modes and remain scoped to hardening behavior" do
    thresholds = ObservabilityContract.operational_slo_thresholds()

    assert Map.keys(thresholds) |> Enum.sort() == Enum.sort(@slo_threshold_names)

    for name <- @slo_threshold_names do
      threshold = Map.fetch!(thresholds, name)

      assert threshold.contract_name == "Platform.OperationalSLOThreshold.v1"
      assert threshold.threshold_name == name
      assert threshold.threshold >= 0
      assert threshold.window_ms > 0
      assert threshold.severity in [:p0, :p1, :p2, :p3]
      assert String.contains?(threshold.metric_ref, ".")
      assert String.contains?(threshold.runbook_ref, "operational_observability.md")
      assert String.contains?(threshold.safe_action, "-")
      assert :ok = OperationalSLO.validate_threshold(threshold)
    end
  end

  test "runbook entries name symptoms commands evidence and escalation" do
    entries = ObservabilityContract.operational_runbook_entries()

    assert Map.keys(entries) |> Enum.sort() ==
             OperationalRunbook.entry_names() |> Enum.sort()

    for name <- @signal_names do
      assert Map.has_key?(entries, name)
    end

    for name <- @slo_threshold_names do
      assert Map.has_key?(entries, name)
    end

    for entry <- Map.values(entries) do
      assert is_binary(entry.symptom)
      assert entry.commands != []
      assert entry.expected_evidence != []
      assert is_binary(entry.escalation)
      assert is_binary(entry.safe_action)
    end

    live_entry = Map.fetch!(entries, :live_provider_effect_status)

    assert "~/scripts/with_bash_secrets mix extravaganza.headless.live.smoke" in live_entry.commands
  end
end
