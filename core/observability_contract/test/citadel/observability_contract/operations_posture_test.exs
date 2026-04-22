defmodule Citadel.ObservabilityContract.OperationsPostureTest do
  use ExUnit.Case, async: true

  alias Citadel.ObservabilityContract
  alias Citadel.ObservabilityContract.OperationsPosture

  @touched_seams [
    :signal_ingress_lineage,
    :trace_publisher_output,
    :aitrace_file_export,
    :audit_fact_append
  ]

  @required_profile_fields [
    :observability_owner,
    :owner_repo,
    :owner_package,
    :surface,
    :event_or_log_name,
    :metric_ref,
    :trace_ref,
    :log_ref,
    :alert_ref,
    :incident_runbook_ref,
    :slo_or_error_budget_ref,
    :severity_mapping,
    :paging_or_triage_route,
    :redaction_policy_ref,
    :retention_ref,
    :sampling_policy_ref,
    :dropped_or_suppressed_count_ref,
    :not_applicable_reason,
    :release_manifest_ref
  ]

  test "facade exposes operations posture ownership" do
    assert ObservabilityContract.operations_posture_module() == OperationsPosture
    assert :observability_operations_posture_v1 in ObservabilityContract.manifest().owns
    assert ObservabilityContract.operations_posture_touched_seams() == @touched_seams
    assert ObservabilityContract.operations_posture_profile_fields() == @required_profile_fields
  end

  test "default profiles cover touched observable seams and required posture fields" do
    profiles = ObservabilityContract.operations_posture_profiles()

    assert profiles |> Map.keys() |> Enum.sort() == Enum.sort(@touched_seams)

    for seam <- @touched_seams do
      profile = Map.fetch!(profiles, seam)
      dumped = OperationsPosture.dump(profile)

      assert profile.contract_name == "Platform.ObservabilityOperationsPosture.v1"
      assert profile.contract_version == "1.0.0"
      assert profile.touched_seam == seam
      assert profile.release_manifest_ref == "phase5-v7-milestone5"

      for field <- @required_profile_fields do
        assert Map.has_key?(dumped, field)
      end

      assert profile.metric_ref =~ "."
      assert profile.trace_ref =~ "."
      assert profile.log_ref =~ "."
      assert profile.alert_ref =~ "."
      assert profile.incident_runbook_ref =~ "runbooks/observability_operations_posture.md"
      assert profile.slo_or_error_budget_ref =~ "."
      assert profile.paging_or_triage_route =~ "-"
      assert profile.redaction_policy_ref == "citadel.redaction.refs_only.v1"
      assert profile.retention_ref == "phase5.observability_evidence.retention.v1"
      assert profile.sampling_policy_ref == "success=100/min;debug=drop;protected=always"
      assert profile.dropped_or_suppressed_count_ref =~ "."
      assert profile.not_applicable_reason == nil
      assert OperationsPosture.alert_route_complete?(profile)
      assert :ok = OperationsPosture.validate_profile(profile)
    end
  end

  test "critical profiles declare severity mapping and operator route evidence" do
    for profile <- Map.values(OperationsPosture.profiles()) do
      assert Enum.all?(profile.severity_mapping, fn {family, severity} ->
               family in OperationsPosture.critical_condition_families() and
                 severity in OperationsPosture.severity_levels()
             end)

      assert Enum.any?(profile.severity_mapping, fn {_family, severity} ->
               severity in [:p0, :p1, :p2]
             end)

      assert is_binary(profile.alert_ref)
      assert is_binary(profile.incident_runbook_ref)
      assert is_binary(profile.slo_or_error_budget_ref)
      assert is_binary(profile.paging_or_triage_route)
      assert is_binary(profile.dropped_or_suppressed_count_ref)
    end
  end

  test "profiles fail closed on missing required operating evidence" do
    base = OperationsPosture.profile!(:audit_fact_append) |> OperationsPosture.dump()

    assert {:error, %ArgumentError{message: message}} =
             base
             |> Map.delete(:log_ref)
             |> OperationsPosture.new()

    assert message =~ "missing required field"

    assert {:error, %ArgumentError{message: message}} =
             base
             |> Map.put(:alert_ref, "")
             |> OperationsPosture.new()

    assert message =~ "non-empty strings"

    assert {:error, %ArgumentError{message: message}} =
             base
             |> Map.delete(:dropped_or_suppressed_count_ref)
             |> OperationsPosture.new()

    assert message =~ "missing required field"
  end

  test "profiles fail closed on unsupported severity posture" do
    base = OperationsPosture.profile!(:trace_publisher_output) |> OperationsPosture.dump()

    assert {:error, %ArgumentError{message: message}} =
             base
             |> Map.put(:severity_mapping, %{observability_overflow: :critical})
             |> OperationsPosture.new()

    assert message =~ "severity_mapping_severity"

    assert {:error, %ArgumentError{message: message}} =
             base
             |> Map.put(:severity_mapping, %{custom_failure: :p1})
             |> OperationsPosture.new()

    assert message =~ "severity_mapping_family"
  end
end
