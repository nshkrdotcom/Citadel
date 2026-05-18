defmodule Citadel.ObservabilityContract.OperationalSignal do
  @moduledoc """
  Backend-neutral operator signal contract for platform health.

  Contract: `Platform.OperationalSignal.v1`.

  These records are for operational health, latency, lag, and error visibility.
  They are intentionally separate from AITrace audit and replay records.
  """

  alias Citadel.ContractCore.AttrMap
  alias Citadel.ObservabilityContract.{CardinalityBounds, OperationsPosture, Telemetry}

  @contract_name "Platform.OperationalSignal.v1"
  @contract_version "1.0.0"
  @release_manifest_ref "phase8-operational-observability"

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

  @signal_kinds [
    :binding_cache,
    :authority,
    :credential_lease,
    :lower_invocation,
    :receipt_reduction,
    :projection_lag,
    :export_lag,
    :provider_effect_status
  ]

  @outcomes [:ok, :error, :degraded, :rejected, :stale, :dropped]

  @fields [
    :contract_name,
    :contract_version,
    :signal_name,
    :signal_kind,
    :owner_repo,
    :owner_package,
    :operation_family,
    :outcome,
    :telemetry_event,
    :measurements,
    :metric_labels,
    :trace_attributes,
    :log_fields,
    :metric_ref,
    :trace_ref,
    :log_ref,
    :runbook_ref,
    :slo_threshold_ref,
    :redaction_policy_ref,
    :safe_action,
    :release_manifest_ref
  ]

  @forbidden_raw_field_names [
    "api_key",
    "arbitrary_payload_map",
    "connector_payload",
    "credential",
    "full_stderr",
    "full_stdout",
    "password",
    "payload",
    "payload_body",
    "payload_map",
    "private_key",
    "prompt_body",
    "provider_request",
    "provider_request_body",
    "provider_response",
    "provider_response_body",
    "raw_payload",
    "raw_prompt",
    "raw_webhook_body",
    "refresh_token",
    "secret",
    "stderr",
    "stdout",
    "tenant_secret",
    "token"
  ]

  @metric_label_keys CardinalityBounds.low_cardinality_metric_label_allowlist()
  @log_field_keys OperationsPosture.safe_log_field_allowlist()
  @trace_attribute_keys CardinalityBounds.profile!(:trace_span).trace_attribute_allowlist

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec signal_names() :: [atom(), ...]
  def signal_names, do: @signal_names

  @spec signal_kinds() :: [atom(), ...]
  def signal_kinds, do: @signal_kinds

  @spec outcomes() :: [atom(), ...]
  def outcomes, do: @outcomes

  @spec fields() :: [atom(), ...]
  def fields, do: @fields

  @spec forbidden_raw_field_names() :: [String.t(), ...]
  def forbidden_raw_field_names, do: @forbidden_raw_field_names

  @spec signals() :: %{required(atom()) => t()}
  def signals, do: Map.new(@signal_names, &{&1, signal!(&1)})

  @spec signal!(atom() | String.t() | map() | keyword()) :: t()
  def signal!(name) when is_atom(name) or is_binary(name) do
    name
    |> default_attrs()
    |> new!()
  end

  def signal!(attrs), do: new!(attrs)

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = signal), do: normalize(signal)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = signal) do
    case normalize(signal) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec validate_signal(t() | map() | keyword()) :: :ok | {:error, Exception.t()}
  def validate_signal(signal) do
    case new(signal) do
      {:ok, _signal} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = signal) do
    Map.new(@fields, &{&1, Map.fetch!(signal, &1)})
  end

  @spec redaction_safe?(term()) :: boolean()
  def redaction_safe?(value), do: find_forbidden_raw_path(value) == nil

  @spec find_forbidden_raw_path(term()) :: [String.t()] | nil
  def find_forbidden_raw_path(value), do: find_forbidden_raw_path(value, [])

  defp default_attrs(:binding_lookup) do
    base_attrs(:binding_lookup, %{
      signal_kind: :binding_cache,
      owner_repo: "mezzanine",
      owner_package: "core/config_registry",
      operation_family: "binding_lookup",
      telemetry_definition: :operational_binding_lookup,
      measurements: %{count: 1, duration_ms: 12, cache_age_ms: 30},
      metric_labels: %{
        event_name: "binding_lookup",
        owner_package: "core/config_registry",
        operation_family: "binding_lookup",
        outcome: "ok",
        reason_code: "active_binding"
      },
      trace_attributes: %{
        trace_id: "trace://operational/binding-lookup",
        tenant_ref: "tenant://redacted",
        operation_family: "binding_lookup",
        safe_action: "continue-with-active-binding"
      },
      log_fields: %{
        event_name: "binding_lookup",
        owner_package: "core/config_registry",
        operation_family: "binding_lookup",
        outcome: "ok",
        reason_code: "active_binding",
        tenant_ref: "tenant://redacted",
        trace_id: "trace://operational/binding-lookup",
        safe_action: "continue-with-active-binding",
        release_manifest_ref: @release_manifest_ref
      },
      slo_threshold_ref: "citadel.slo.binding_cache_stale_reads",
      safe_action: "fail-closed-on-stale-binding-cache"
    })
  end

  defp default_attrs(:authority_decision) do
    base_attrs(:authority_decision, %{
      signal_kind: :authority,
      owner_repo: "citadel",
      owner_package: "core/citadel_kernel",
      operation_family: "authority_decision",
      telemetry_definition: :operational_authority_decision,
      measurements: %{count: 1, duration_ms: 9},
      metric_labels: %{
        event_name: "authority_decision",
        owner_package: "core/citadel_kernel",
        operation_family: "authority_decision",
        outcome: "ok",
        safe_action: "allow-authorized-operation"
      },
      trace_attributes: %{
        trace_id: "trace://operational/authority",
        tenant_ref: "tenant://redacted",
        operation_family: "authority_decision",
        safe_action: "allow-authorized-operation"
      },
      log_fields: %{
        event_name: "authority_decision",
        owner_package: "core/citadel_kernel",
        operation_family: "authority_decision",
        outcome: "ok",
        tenant_ref: "tenant://redacted",
        authority_ref: "authority://redacted",
        trace_id: "trace://operational/authority",
        safe_action: "allow-authorized-operation",
        release_manifest_ref: @release_manifest_ref
      },
      slo_threshold_ref: "citadel.slo.tenant_bypass_attempts",
      safe_action: "reject-cross-tenant-authority-bypass"
    })
  end

  defp default_attrs(:credential_lease_materialization) do
    base_attrs(:credential_lease_materialization, %{
      signal_kind: :credential_lease,
      owner_repo: "jido_integration",
      owner_package: "core/auth",
      operation_family: "credential_lease_materialization",
      telemetry_definition: :operational_credential_lease_materialization,
      measurements: %{count: 1, duration_ms: 18},
      metric_labels: %{
        event_name: "credential_lease_materialization",
        owner_package: "core/auth",
        operation_family: "credential_lease_materialization",
        outcome: "ok",
        connector_family: "http_connector"
      },
      trace_attributes: %{
        trace_id: "trace://operational/credential-lease",
        tenant_ref: "tenant://redacted",
        operation_family: "credential_lease_materialization",
        safe_action: "materialize-lease-from-handle-ref"
      },
      log_fields: %{
        event_name: "credential_lease_materialization",
        owner_package: "core/auth",
        operation_family: "credential_lease_materialization",
        outcome: "ok",
        tenant_ref: "tenant://redacted",
        trace_id: "trace://operational/credential-lease",
        artifact_ref: "credential-lease://redacted",
        safe_action: "materialize-lease-from-handle-ref",
        release_manifest_ref: @release_manifest_ref
      },
      slo_threshold_ref: "citadel.slo.external_secret_resolver_failures",
      safe_action: "fail-closed-without-raw-secret-egress"
    })
  end

  defp default_attrs(:lower_invocation) do
    base_attrs(:lower_invocation, %{
      signal_kind: :lower_invocation,
      owner_repo: "mezzanine",
      owner_package: "bridges/integration_bridge",
      operation_family: "lower_invocation",
      telemetry_definition: :operational_lower_invocation,
      measurements: %{count: 1, duration_ms: 44, retry_count: 0},
      metric_labels: %{
        event_name: "lower_invocation",
        owner_package: "bridges/integration_bridge",
        operation_family: "lower_invocation",
        outcome: "ok",
        retry_posture: "not_retried"
      },
      trace_attributes: %{
        trace_id: "trace://operational/lower-invocation",
        tenant_ref: "tenant://redacted",
        operation_family: "lower_invocation",
        safe_action: "invoke-through-binding-descriptor"
      },
      log_fields: %{
        event_name: "lower_invocation",
        owner_package: "bridges/integration_bridge",
        operation_family: "lower_invocation",
        outcome: "ok",
        tenant_ref: "tenant://redacted",
        trace_id: "trace://operational/lower-invocation",
        safe_action: "invoke-through-binding-descriptor",
        release_manifest_ref: @release_manifest_ref
      },
      slo_threshold_ref: "citadel.slo.lower_provider_error_rate",
      safe_action: "route-provider-error-without-control-branch"
    })
  end

  defp default_attrs(:receipt_reduction) do
    base_attrs(:receipt_reduction, %{
      signal_kind: :receipt_reduction,
      owner_repo: "mezzanine",
      owner_package: "core/evidence_engine",
      operation_family: "receipt_reduction",
      telemetry_definition: :operational_receipt_reduction,
      measurements: %{count: 1, duration_ms: 7},
      metric_labels: %{
        event_name: "receipt_reduction",
        owner_package: "core/evidence_engine",
        operation_family: "receipt_reduction",
        outcome: "ok"
      },
      trace_attributes: %{
        trace_id: "trace://operational/receipt-reduction",
        tenant_ref: "tenant://redacted",
        operation_family: "receipt_reduction",
        safe_action: "derive-disposition-from-lineage"
      },
      log_fields: %{
        event_name: "receipt_reduction",
        owner_package: "core/evidence_engine",
        operation_family: "receipt_reduction",
        outcome: "ok",
        tenant_ref: "tenant://redacted",
        trace_id: "trace://operational/receipt-reduction",
        safe_action: "derive-disposition-from-lineage",
        release_manifest_ref: @release_manifest_ref
      },
      slo_threshold_ref: "citadel.slo.trace_export_drops",
      safe_action: "emit-reduction-gap-without-raw-output"
    })
  end

  defp default_attrs(:projection_lag) do
    base_attrs(:projection_lag, %{
      signal_kind: :projection_lag,
      owner_repo: "app_kit",
      owner_package: "bridges/projection_bridge",
      operation_family: "projection_lag",
      telemetry_definition: :operational_projection_lag,
      measurements: %{lag_ms: 80, queue_depth: 2},
      metric_labels: %{
        event_name: "projection_lag",
        owner_package: "bridges/projection_bridge",
        operation_family: "projection_lag",
        outcome: "ok",
        queue_family: "projection"
      },
      trace_attributes: %{
        trace_id: "trace://operational/projection-lag",
        tenant_ref: "tenant://redacted",
        operation_family: "projection_lag",
        safe_action: "show-operator-lag-status"
      },
      log_fields: %{
        event_name: "projection_lag",
        owner_package: "bridges/projection_bridge",
        operation_family: "projection_lag",
        outcome: "ok",
        tenant_ref: "tenant://redacted",
        trace_id: "trace://operational/projection-lag",
        safe_action: "show-operator-lag-status",
        release_manifest_ref: @release_manifest_ref
      },
      slo_threshold_ref: "citadel.slo.projection_lag",
      safe_action: "surface-projection-staleness"
    })
  end

  defp default_attrs(:aitrace_export_lag) do
    base_attrs(:aitrace_export_lag, %{
      signal_kind: :export_lag,
      owner_repo: "AITrace",
      owner_package: "core/replay_engine",
      operation_family: "aitrace_export_lag",
      telemetry_definition: :operational_aitrace_export_lag,
      measurements: %{lag_ms: 120, queue_depth: 1, dropped_count: 0},
      metric_labels: %{
        event_name: "aitrace_export_lag",
        owner_package: "core/replay_engine",
        operation_family: "aitrace_export_lag",
        outcome: "ok",
        queue_family: "trace_export"
      },
      trace_attributes: %{
        trace_id: "trace://operational/aitrace-export-lag",
        tenant_ref: "tenant://redacted",
        operation_family: "aitrace_export_lag",
        safe_action: "surface-export-lag"
      },
      log_fields: %{
        event_name: "aitrace_export_lag",
        owner_package: "core/replay_engine",
        operation_family: "aitrace_export_lag",
        outcome: "ok",
        tenant_ref: "tenant://redacted",
        trace_id: "trace://operational/aitrace-export-lag",
        dropped_count: 0,
        safe_action: "surface-export-lag",
        release_manifest_ref: @release_manifest_ref
      },
      slo_threshold_ref: "citadel.slo.trace_export_drops",
      safe_action: "route-export-lag-to-operators"
    })
  end

  defp default_attrs(:live_provider_effect_status) do
    base_attrs(:live_provider_effect_status, %{
      signal_kind: :provider_effect_status,
      owner_repo: "extravaganza",
      owner_package: "apps/extravaganza_core",
      operation_family: "live_provider_effect_status",
      telemetry_definition: :operational_live_provider_effect_status,
      measurements: %{count: 1, duration_ms: 95, retry_count: 0},
      metric_labels: %{
        event_name: "live_provider_effect_status",
        owner_package: "apps/extravaganza_core",
        operation_family: "live_provider_effect_status",
        outcome: "ok",
        connector_family: "product_live_provider"
      },
      trace_attributes: %{
        trace_id: "trace://operational/live-provider-effect",
        tenant_ref: "tenant://redacted",
        operation_family: "live_provider_effect_status",
        safe_action: "record-live-effect-status"
      },
      log_fields: %{
        event_name: "live_provider_effect_status",
        owner_package: "apps/extravaganza_core",
        operation_family: "live_provider_effect_status",
        outcome: "ok",
        tenant_ref: "tenant://redacted",
        trace_id: "trace://operational/live-provider-effect",
        safe_action: "record-live-effect-status",
        release_manifest_ref: @release_manifest_ref
      },
      slo_threshold_ref: "citadel.slo.lower_provider_error_rate",
      safe_action: "operator-status-only-control-stays-generic"
    })
  end

  defp default_attrs(signal_name) do
    signal_name = enum_atom!(signal_name, :signal_name, @signal_names)
    default_attrs(signal_name)
  end

  defp base_attrs(signal_name, attrs) do
    telemetry_definition = Map.fetch!(attrs, :telemetry_definition)
    telemetry_event = Telemetry.event_name(telemetry_definition)

    Map.merge(
      %{
        contract_name: @contract_name,
        contract_version: @contract_version,
        signal_name: signal_name,
        outcome: :ok,
        telemetry_event: telemetry_event,
        metric_ref: "metric://citadel/operational/#{signal_name}",
        trace_ref: "trace://citadel/operational/#{signal_name}",
        log_ref: "log://citadel/operational/#{signal_name}",
        runbook_ref: "docs/runbooks/operational_observability.md##{signal_name}",
        redaction_policy_ref: "citadel.redaction.refs_only.v1",
        release_manifest_ref: @release_manifest_ref
      },
      Map.delete(attrs, :telemetry_definition)
    )
  end

  defp build!(attrs) do
    attrs = AttrMap.normalize!(attrs, @contract_name)
    metric_labels = keyed_map!(attrs, :metric_labels, @metric_label_keys)
    trace_attributes = keyed_map!(attrs, :trace_attributes, @trace_attribute_keys)
    log_fields = keyed_map!(attrs, :log_fields, @log_field_keys)

    validate_metric_labels!(Map.keys(metric_labels))
    validate_log_fields!(Map.keys(log_fields))
    ensure_redaction_safe!(metric_labels, :metric_labels)
    ensure_redaction_safe!(trace_attributes, :trace_attributes)
    ensure_redaction_safe!(log_fields, :log_fields)

    signal = %__MODULE__{
      contract_name:
        attrs
        |> AttrMap.get(:contract_name, @contract_name)
        |> literal!(@contract_name, :contract_name),
      contract_version:
        attrs
        |> AttrMap.get(:contract_version, @contract_version)
        |> literal!(@contract_version, :contract_version),
      signal_name:
        attrs
        |> AttrMap.fetch!(:signal_name, @contract_name)
        |> enum_atom!(:signal_name, @signal_names),
      signal_kind:
        attrs
        |> AttrMap.fetch!(:signal_kind, @contract_name)
        |> enum_atom!(:signal_kind, @signal_kinds),
      owner_repo: required_string!(attrs, :owner_repo),
      owner_package: required_string!(attrs, :owner_package),
      operation_family: required_string!(attrs, :operation_family),
      outcome:
        attrs
        |> AttrMap.fetch!(:outcome, @contract_name)
        |> enum_atom!(:outcome, @outcomes),
      telemetry_event: telemetry_event!(attrs),
      measurements: measurements!(attrs),
      metric_labels: metric_labels,
      trace_attributes: trace_attributes,
      log_fields: log_fields,
      metric_ref: required_string!(attrs, :metric_ref),
      trace_ref: required_string!(attrs, :trace_ref),
      log_ref: required_string!(attrs, :log_ref),
      runbook_ref: required_string!(attrs, :runbook_ref),
      slo_threshold_ref: required_string!(attrs, :slo_threshold_ref),
      redaction_policy_ref:
        attrs
        |> AttrMap.fetch!(:redaction_policy_ref, @contract_name)
        |> literal!("citadel.redaction.refs_only.v1", :redaction_policy_ref),
      safe_action: required_string!(attrs, :safe_action),
      release_manifest_ref: required_string!(attrs, :release_manifest_ref)
    }

    ensure_consistent_signal!(signal)
    signal
  end

  defp normalize(%__MODULE__{} = signal) do
    {:ok, signal |> dump() |> build!()}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp validate_metric_labels!(keys) do
    case CardinalityBounds.validate_metric_labels(keys) do
      :ok ->
        :ok

      {:error, reason} ->
        raise ArgumentError,
              "#{@contract_name}.metric_labels are not low-cardinality: #{inspect(reason)}"
    end
  end

  defp validate_log_fields!(keys) do
    case OperationsPosture.validate_log_fields(keys) do
      :ok ->
        :ok

      {:error, reason} ->
        raise ArgumentError,
              "#{@contract_name}.log_fields are not redaction-safe: #{inspect(reason)}"
    end
  end

  defp ensure_consistent_signal!(%__MODULE__{} = signal) do
    metric_event_name = Map.get(signal.metric_labels, :event_name)
    log_event_name = Map.get(signal.log_fields, :event_name)
    expected = Atom.to_string(signal.signal_name)

    cond do
      metric_event_name != expected ->
        raise ArgumentError, "#{@contract_name}.metric_labels.event_name must be #{expected}"

      log_event_name != expected ->
        raise ArgumentError, "#{@contract_name}.log_fields.event_name must be #{expected}"

      signal.operation_family != expected ->
        raise ArgumentError, "#{@contract_name}.operation_family must be #{expected}"

      true ->
        :ok
    end
  end

  defp telemetry_event!(attrs) do
    attrs
    |> AttrMap.fetch!(:telemetry_event, @contract_name)
    |> case do
      value when is_list(value) and value != [] ->
        if Enum.all?(value, &is_atom/1) do
          value
        else
          raise ArgumentError,
                "#{@contract_name}.telemetry_event must be an atom list, got #{inspect(value)}"
        end

      value ->
        raise ArgumentError,
              "#{@contract_name}.telemetry_event must be an atom list, got #{inspect(value)}"
    end
  end

  defp measurements!(attrs) do
    attrs
    |> AttrMap.fetch!(:measurements, @contract_name)
    |> case do
      values when is_map(values) and map_size(values) > 0 ->
        Map.new(values, fn {key, value} ->
          {measurement_key!(key), non_negative_number!(value, key)}
        end)

      value ->
        raise ArgumentError,
              "#{@contract_name}.measurements must be a non-empty map, got #{inspect(value)}"
    end
  end

  defp measurement_key!(key) when is_atom(key), do: key

  defp measurement_key!(key) do
    raise ArgumentError,
          "#{@contract_name}.measurement key must be an atom, got #{inspect(key)}"
  end

  defp non_negative_number!(value, _key) when is_integer(value) and value >= 0, do: value
  defp non_negative_number!(value, _key) when is_float(value) and value >= 0.0, do: value

  defp non_negative_number!(value, key) do
    raise ArgumentError,
          "#{@contract_name}.measurements.#{key} must be a non-negative number, got #{inspect(value)}"
  end

  defp keyed_map!(attrs, key, allowed_keys) do
    attrs
    |> AttrMap.fetch!(key, @contract_name)
    |> case do
      values when is_map(values) and map_size(values) > 0 ->
        Map.new(values, fn {entry_key, value} ->
          {enum_atom!(entry_key, key, allowed_keys), safe_scalar!(value, key)}
        end)

      value ->
        raise ArgumentError,
              "#{@contract_name}.#{key} must be a non-empty map, got #{inspect(value)}"
    end
  end

  defp safe_scalar!(value, _key) when is_binary(value) or is_atom(value) or is_integer(value),
    do: value

  defp safe_scalar!(value, _key) when is_float(value) or is_boolean(value), do: value

  defp safe_scalar!(nil, _key), do: nil

  defp safe_scalar!(value, key) do
    raise ArgumentError,
          "#{@contract_name}.#{key} values must be scalar refs, codes, or counters, got #{inspect(value)}"
  end

  defp ensure_redaction_safe!(value, label) do
    case find_forbidden_raw_path(value) do
      nil ->
        :ok

      path ->
        raise ArgumentError,
              "#{@contract_name}.#{label} contains forbidden raw field path #{Enum.join(path, ".")}"
    end
  end

  defp find_forbidden_raw_path(%{} = value, path) do
    Enum.find_value(value, fn {key, child} ->
      key_name = normalized_key_name(key)

      if key_name in @forbidden_raw_field_names do
        Enum.reverse([key_name | path])
      else
        find_forbidden_raw_path(child, [key_name | path])
      end
    end)
  end

  defp find_forbidden_raw_path(values, path) when is_list(values) do
    values
    |> Enum.with_index()
    |> Enum.find_value(fn {value, index} ->
      find_forbidden_raw_path(value, [Integer.to_string(index) | path])
    end)
  end

  defp find_forbidden_raw_path(_value, _path), do: nil

  defp normalized_key_name(key) when is_atom(key), do: Atom.to_string(key)

  defp normalized_key_name(key) when is_binary(key),
    do: key |> String.downcase() |> String.trim()

  defp normalized_key_name(key), do: inspect(key)

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
          "#{@contract_name}.#{key} must be a non-empty string, got #{inspect(value)}"
  end

  defp literal!(value, expected, _key) when value == expected, do: value

  defp literal!(value, expected, key) do
    raise ArgumentError, "#{@contract_name}.#{key} must be #{expected}, got #{inspect(value)}"
  end

  defp enum_atom!(value, key, allowed) when is_atom(value) do
    if value in allowed do
      value
    else
      raise ArgumentError,
            "#{@contract_name}.#{key} must be one of #{inspect(allowed)}, got #{inspect(value)}"
    end
  end

  defp enum_atom!(value, key, allowed) when is_binary(value) do
    Enum.find(allowed, &(Atom.to_string(&1) == value)) ||
      raise ArgumentError, "#{@contract_name}.#{key} must be one of #{inspect(allowed)}"
  end

  defp enum_atom!(value, key, allowed) do
    raise ArgumentError,
          "#{@contract_name}.#{key} must be one of #{inspect(allowed)}, got #{inspect(value)}"
  end
end
