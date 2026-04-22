defmodule Citadel.ObservabilityContract.OperationsPosture do
  @moduledoc """
  Backend-neutral operations posture profile for touched observable seams.

  Contract: `Platform.ObservabilityOperationsPosture.v1`.
  """

  alias Citadel.ContractCore.AttrMap

  @contract_name "Platform.ObservabilityOperationsPosture.v1"
  @contract_version "1.0.0"

  @touched_seams [
    :signal_ingress_lineage,
    :trace_publisher_output,
    :aitrace_file_export,
    :audit_fact_append
  ]

  @profile_fields [
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

  @fields [:contract_name, :contract_version, :touched_seam] ++ @profile_fields

  @severity_levels [:p0, :p1, :p2, :p3]

  @critical_condition_families [
    :fail_closed_security,
    :tenant_authority_bypass,
    :data_loss_restore_failure,
    :version_skew_rejection_spike,
    :queue_mailbox_overflow,
    :lease_revocation_bound_miss,
    :artifact_schema_hash_rejection_spike,
    :observability_overflow
  ]

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec touched_seams() :: [atom(), ...]
  def touched_seams, do: @touched_seams

  @spec profile_fields() :: [atom(), ...]
  def profile_fields, do: @profile_fields

  @spec severity_levels() :: [atom(), ...]
  def severity_levels, do: @severity_levels

  @spec critical_condition_families() :: [atom(), ...]
  def critical_condition_families, do: @critical_condition_families

  @spec profiles() :: %{required(atom()) => t()}
  def profiles, do: Map.new(@touched_seams, &{&1, profile!(&1)})

  @spec profile!(atom() | String.t() | map() | keyword()) :: t()
  def profile!(seam) when is_atom(seam) or is_binary(seam) do
    seam
    |> default_attrs()
    |> new!()
  end

  def profile!(attrs), do: new!(attrs)

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = profile), do: normalize(profile)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = profile) do
    case normalize(profile) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec validate_profile(t() | map() | keyword()) :: :ok | {:error, Exception.t()}
  def validate_profile(profile) do
    case new(profile) do
      {:ok, _profile} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = profile) do
    Map.new(@fields, &{&1, Map.fetch!(profile, &1)})
  end

  @spec alert_route_complete?(t()) :: boolean()
  def alert_route_complete?(%__MODULE__{} = profile) do
    required_route_refs_present?(profile) and critical_severity_mapping?(profile.severity_mapping)
  end

  defp default_attrs(:signal_ingress_lineage) do
    base_attrs(:signal_ingress_lineage, %{
      observability_owner: "citadel-runtime",
      owner_repo: "citadel",
      owner_package: "core/citadel_kernel",
      surface: "dangerous_ingress",
      event_or_log_name: "citadel.signal_ingress.lineage_admission",
      metric_ref: "citadel.signal_ingress.lineage_admission.count",
      trace_ref: "Citadel.TraceEnvelope.signal_ingress_lineage",
      log_ref: "citadel.kernel.signal_ingress.lineage_admission",
      alert_ref: "citadel.alert.signal_ingress.lineage_rejection_spike",
      incident_runbook_ref: "runbooks/observability_operations_posture.md#signal-ingress-lineage",
      slo_or_error_budget_ref: "citadel.slo.fail_closed_admission_latency",
      severity_mapping: %{
        fail_closed_security: :p1,
        tenant_authority_bypass: :p0,
        observability_overflow: :p1
      },
      paging_or_triage_route: "citadel-runtime-triage",
      dropped_or_suppressed_count_ref: "citadel.signal_ingress.lineage_rejected.count"
    })
  end

  defp default_attrs(:trace_publisher_output) do
    base_attrs(:trace_publisher_output, %{
      observability_owner: "citadel-runtime",
      owner_repo: "citadel",
      owner_package: "core/citadel_kernel",
      surface: "trace_publication",
      event_or_log_name: "citadel.trace_publisher.publish",
      metric_ref: "citadel.trace_publisher.output.count",
      trace_ref: "Citadel.TraceEnvelope.trace_publisher",
      log_ref: "citadel.kernel.trace_publisher.output",
      alert_ref: "citadel.alert.trace_publisher.protected_overflow",
      incident_runbook_ref: "runbooks/observability_operations_posture.md#trace-publisher-output",
      slo_or_error_budget_ref: "citadel.error_budget.protected_trace_visibility",
      severity_mapping: %{
        data_loss_restore_failure: :p1,
        observability_overflow: :p1
      },
      paging_or_triage_route: "citadel-runtime-triage",
      dropped_or_suppressed_count_ref: "citadel.trace_publisher.dropped_or_rate_limited.count"
    })
  end

  defp default_attrs(:aitrace_file_export) do
    base_attrs(:aitrace_file_export, %{
      observability_owner: "aitrace-runtime",
      owner_repo: "AITrace",
      owner_package: "lib/aitrace/exporter",
      surface: "trace_export",
      event_or_log_name: "aitrace.file_export.receipt",
      metric_ref: "aitrace.file_export.write.count",
      trace_ref: "aitrace.file_export.trace_artifact_sha256",
      log_ref: "aitrace.exporter.file.receipt",
      alert_ref: "aitrace.alert.file_export_rejection_or_unanchored_proof",
      incident_runbook_ref: "runbooks/observability_operations_posture.md#aitrace-file-export",
      slo_or_error_budget_ref: "aitrace.error_budget.bounded_export_failure_visibility",
      severity_mapping: %{
        data_loss_restore_failure: :p1,
        observability_overflow: :p1
      },
      paging_or_triage_route: "aitrace-runtime-triage",
      dropped_or_suppressed_count_ref: "aitrace.file_export.rejected_or_unanchored.count"
    })
  end

  defp default_attrs(:audit_fact_append) do
    base_attrs(:audit_fact_append, %{
      observability_owner: "mezzanine-audit",
      owner_repo: "mezzanine",
      owner_package: "core/audit_engine",
      surface: "audit_fact",
      event_or_log_name: "mezzanine.audit_append.append_or_aggregate",
      metric_ref: "mezzanine.audit_append.observability_counts",
      trace_ref: "mezzanine.audit.execution_lineage.trace_id",
      log_ref: "mezzanine.audit.append.redacted",
      alert_ref: "mezzanine.alert.audit_append_rejection_or_overflow",
      incident_runbook_ref: "runbooks/observability_operations_posture.md#audit-fact-append",
      slo_or_error_budget_ref: "mezzanine.error_budget.audit_failure_visibility",
      severity_mapping: %{
        fail_closed_security: :p1,
        tenant_authority_bypass: :p0,
        artifact_schema_hash_rejection_spike: :p1,
        observability_overflow: :p1
      },
      paging_or_triage_route: "mezzanine-audit-triage",
      dropped_or_suppressed_count_ref: "mezzanine.audit_append.observability_counts.v1"
    })
  end

  defp default_attrs(seam) do
    seam = enum_atom!(seam, :touched_seam, @touched_seams)
    default_attrs(seam)
  end

  defp base_attrs(seam, attrs) do
    Map.merge(
      %{
        contract_name: @contract_name,
        contract_version: @contract_version,
        touched_seam: seam,
        redaction_policy_ref: "citadel.redaction.refs_only.v1",
        retention_ref: "phase5.observability_evidence.retention.v1",
        sampling_policy_ref: "success=100/min;debug=drop;protected=always",
        not_applicable_reason: nil,
        release_manifest_ref: "phase5-v7-milestone5"
      },
      attrs
    )
  end

  defp build!(attrs) do
    attrs = AttrMap.normalize!(attrs, @contract_name)
    severity_mapping = severity_mapping!(attrs)

    profile = %__MODULE__{
      contract_name:
        attrs
        |> AttrMap.get(:contract_name, @contract_name)
        |> literal!(@contract_name, :contract_name),
      contract_version:
        attrs
        |> AttrMap.get(:contract_version, @contract_version)
        |> literal!(@contract_version, :contract_version),
      touched_seam:
        attrs
        |> AttrMap.fetch!(:touched_seam, @contract_name)
        |> enum_atom!(:touched_seam, @touched_seams),
      observability_owner: required_string!(attrs, :observability_owner),
      owner_repo: required_string!(attrs, :owner_repo),
      owner_package: required_string!(attrs, :owner_package),
      surface: required_string!(attrs, :surface),
      event_or_log_name: required_string!(attrs, :event_or_log_name),
      metric_ref: required_string!(attrs, :metric_ref),
      trace_ref: required_string!(attrs, :trace_ref),
      log_ref: required_string!(attrs, :log_ref),
      alert_ref: required_string!(attrs, :alert_ref),
      incident_runbook_ref: required_string!(attrs, :incident_runbook_ref),
      slo_or_error_budget_ref: required_string!(attrs, :slo_or_error_budget_ref),
      severity_mapping: severity_mapping,
      paging_or_triage_route: required_string!(attrs, :paging_or_triage_route),
      redaction_policy_ref: required_string!(attrs, :redaction_policy_ref),
      retention_ref: required_string!(attrs, :retention_ref),
      sampling_policy_ref: required_string!(attrs, :sampling_policy_ref),
      dropped_or_suppressed_count_ref: required_string!(attrs, :dropped_or_suppressed_count_ref),
      not_applicable_reason: optional_string!(attrs, :not_applicable_reason),
      release_manifest_ref: required_string!(attrs, :release_manifest_ref)
    }

    ensure_alert_route_complete!(profile)
    profile
  end

  defp normalize(%__MODULE__{} = profile) do
    {:ok, profile |> dump() |> build!()}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp ensure_alert_route_complete!(%__MODULE__{} = profile) do
    if alert_route_complete?(profile) do
      :ok
    else
      raise ArgumentError,
            "#{@contract_name} critical observable seams require alert, runbook, SLO/error-budget, triage route, and P0/P1/P2 severity mapping"
    end
  end

  defp required_route_refs_present?(%__MODULE__{} = profile) do
    Enum.all?(
      [
        profile.alert_ref,
        profile.incident_runbook_ref,
        profile.slo_or_error_budget_ref,
        profile.paging_or_triage_route,
        profile.dropped_or_suppressed_count_ref
      ],
      &non_empty_string?/1
    )
  end

  defp critical_severity_mapping?(severity_mapping) do
    Enum.any?(severity_mapping, fn {family, severity} ->
      family in @critical_condition_families and severity in [:p0, :p1, :p2]
    end)
  end

  defp severity_mapping!(attrs) do
    attrs
    |> AttrMap.fetch!(:severity_mapping, @contract_name)
    |> case do
      values when is_map(values) and map_size(values) > 0 ->
        Map.new(values, fn {family, severity} ->
          {
            enum_atom!(family, :severity_mapping_family, @critical_condition_families),
            enum_atom!(severity, :severity_mapping_severity, @severity_levels)
          }
        end)

      value ->
        raise ArgumentError,
              "#{@contract_name}.severity_mapping must be a non-empty map, got: #{inspect(value)}"
    end
  end

  defp optional_string!(attrs, key) do
    case AttrMap.get(attrs, key, nil) do
      nil -> nil
      value -> string!(value, key)
    end
  end

  defp required_string!(attrs, key) do
    attrs
    |> AttrMap.fetch!(key, @contract_name)
    |> string!(key)
  end

  defp string!(value, _key) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "#{@contract_name} fields must be non-empty strings"
    end

    value
  end

  defp string!(value, key) do
    raise ArgumentError,
          "#{@contract_name}.#{key} must be a non-empty string, got: #{inspect(value)}"
  end

  defp non_empty_string?(value), do: is_binary(value) and String.trim(value) != ""

  defp literal!(value, expected, _key) when value == expected, do: value

  defp literal!(value, expected, key) do
    raise ArgumentError, "#{@contract_name}.#{key} must be #{expected}, got: #{inspect(value)}"
  end

  defp enum_atom!(value, key, allowed) when is_atom(value) do
    if value in allowed do
      value
    else
      raise ArgumentError,
            "#{@contract_name}.#{key} must be one of #{inspect(allowed)}, got: #{inspect(value)}"
    end
  end

  defp enum_atom!(value, key, allowed) when is_binary(value) do
    Enum.find(allowed, &(Atom.to_string(&1) == value)) ||
      raise ArgumentError, "#{@contract_name}.#{key} must be one of #{inspect(allowed)}"
  end

  defp enum_atom!(value, key, allowed) do
    raise ArgumentError,
          "#{@contract_name}.#{key} must be one of #{inspect(allowed)}, got: #{inspect(value)}"
  end
end
