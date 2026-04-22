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
    :log_field_allowlist,
    :log_field_blocklist,
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
      assert profile.log_field_allowlist == OperationsPosture.safe_log_field_allowlist()
      assert profile.log_field_blocklist == OperationsPosture.raw_log_field_blocklist()
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

  test "log fields allow redacted refs and reject raw payload data" do
    assert :ok =
             OperationsPosture.validate_log_fields([
               :event_name,
               :owner_package,
               :safe_action,
               :trace_id,
               :causation_id,
               :canonical_idempotency_key,
               :tenant_ref,
               :release_manifest_ref,
               :payload_hash,
               :suppressed_count
             ])

    assert {:error, {:blocked_log_fields, [:raw_prompt, :tenant_secret, :stdout]}} =
             OperationsPosture.validate_log_fields([:raw_prompt, :tenant_secret, :stdout])

    assert {:error, {:unknown_log_fields, [:custom_payload_map]}} =
             OperationsPosture.validate_log_fields([:custom_payload_map])
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
      assert OperationsPosture.missing_operating_dimensions(profile) == []
      assert OperationsPosture.not_applicable_evidence_complete?(profile)
    end
  end

  test "profiles fail closed on missing required operating evidence" do
    base = OperationsPosture.profile!(:audit_fact_append) |> OperationsPosture.dump()

    assert {:error, %ArgumentError{message: message}} =
             base
             |> Map.delete(:log_ref)
             |> OperationsPosture.new()

    assert message =~ "source-backed not-applicable evidence"

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

  test "profiles fail closed when log blocklists omit prohibited raw fields" do
    base = OperationsPosture.profile!(:signal_ingress_lineage) |> OperationsPosture.dump()

    assert {:error, %ArgumentError{message: message}} =
             base
             |> Map.update!(:log_field_blocklist, &List.delete(&1, :raw_prompt))
             |> OperationsPosture.new()

    assert message =~ "must include raw log fields"

    assert {:error, %ArgumentError{message: message}} =
             base
             |> Map.update!(:log_field_allowlist, &[:raw_prompt | &1])
             |> OperationsPosture.new()

    assert message =~ "overlaps with its blocklist"
  end

  test "source-backed not-applicable evidence can close a missing operating dimension" do
    attrs =
      :aitrace_file_export
      |> OperationsPosture.profile!()
      |> OperationsPosture.dump()
      |> Map.put(:slo_or_error_budget_ref, nil)
      |> Map.put(:not_applicable_reason, %{
        slo_or_error_budget_ref: %{
          reason_ref: "source:no-dedicated-product-slo-for-local-file-export",
          source_evidence_ref: "AITrace/lib/aitrace/exporter/file.ex:receipt_authoritative?",
          owner: "aitrace-runtime",
          safe_action: "use-bounded-export-failure-visibility-runbook"
        }
      })

    assert {:ok, profile} = OperationsPosture.new(attrs)
    assert OperationsPosture.missing_operating_dimensions(profile) == [:slo_or_error_budget_ref]
    assert OperationsPosture.not_applicable_evidence_complete?(profile)
    assert OperationsPosture.alert_route_complete?(profile)
  end

  test "metrics-only or traces-only posture cannot close with not-applicable evidence" do
    not_applicable_reason =
      Map.new(OperationsPosture.not_applicable_dimensions(), fn dimension ->
        {dimension,
         %{
           reason_ref: "source:not-applicable",
           source_evidence_ref: "source/#{dimension}",
           owner: "citadel-runtime",
           safe_action: "block-closeout"
         }}
      end)

    attrs =
      :signal_ingress_lineage
      |> OperationsPosture.profile!()
      |> OperationsPosture.dump()
      |> Map.put(:log_ref, nil)
      |> Map.put(:alert_ref, nil)
      |> Map.put(:incident_runbook_ref, nil)
      |> Map.put(:slo_or_error_budget_ref, nil)
      |> Map.put(:not_applicable_reason, not_applicable_reason)

    assert {:error, %ArgumentError{message: message}} = OperationsPosture.new(attrs)
    assert message =~ "critical observable seams require"
  end

  test "missing not-applicable source evidence fails closed" do
    attrs =
      :trace_publisher_output
      |> OperationsPosture.profile!()
      |> OperationsPosture.dump()
      |> Map.put(:alert_ref, nil)
      |> Map.put(:not_applicable_reason, %{
        alert_ref: %{
          reason_ref: "source:no-alert-needed",
          owner: "citadel-runtime",
          safe_action: "block-closeout"
        }
      })

    assert {:error, %ArgumentError{message: message}} = OperationsPosture.new(attrs)
    assert message =~ "source_evidence_ref"
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
