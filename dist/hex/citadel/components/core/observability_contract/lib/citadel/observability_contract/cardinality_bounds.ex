defmodule Citadel.ObservabilityContract.CardinalityBounds do
  @moduledoc """
  Backend-neutral observability cardinality bounds profile.

  Contract: `Platform.ObservabilityCardinalityBounds.v1`.
  """

  alias Citadel.ContractCore.AttrMap

  @contract_name "Platform.ObservabilityCardinalityBounds.v1"
  @contract_version "1.0.0"

  @surfaces [
    :metric,
    :trace_span,
    :trace_event,
    :trace_export,
    :audit_fact,
    :audit_export,
    :incident_export
  ]

  @profile_fields [
    :observability_surface,
    :owner_repo,
    :owner_package,
    :event_name,
    :metric_label_allowlist,
    :metric_label_blocklist,
    :max_label_keys,
    :max_distinct_label_values_per_window,
    :label_window_ms,
    :trace_attribute_allowlist,
    :trace_attribute_blocklist,
    :max_attributes_per_span,
    :max_events_per_span,
    :max_attribute_key_bytes,
    :max_attribute_value_bytes,
    :max_collection_items,
    :max_map_depth,
    :sample_policy,
    :sample_rate_or_budget,
    :audit_amplification_guard_ref,
    :audit_event_admission_key,
    :audit_event_window_ms,
    :max_audit_events_per_key_per_window,
    :audit_repeat_aggregation_ref,
    :audit_overflow_counter_ref,
    :redaction_policy_ref,
    :hash_or_tokenize_fields,
    :spillover_artifact_policy,
    :overflow_safe_action,
    :release_manifest_ref
  ]

  @fields [:contract_name, :contract_version] ++ @profile_fields

  @sample_policies [
    :always_keep_security,
    :always_keep_fail_closed,
    :rate_limit_success,
    :tail_sample_incident,
    :drop_debug
  ]

  @overflow_safe_actions [
    :drop_attribute,
    :truncate_value,
    :hash_value,
    :spill_to_artifact,
    :sample_out,
    :reject_export
  ]

  @low_cardinality_metric_label_allowlist [
    :event_name,
    :owner_package,
    :operation_family,
    :outcome,
    :error_class,
    :retry_posture,
    :safe_action,
    :queue_family,
    :connector_family,
    :reason_code,
    :reason_family,
    :priority_class,
    :source,
    :status,
    :action_kind,
    :delivery_order_scope,
    :replay_action,
    :dropped_family,
    :dropped_family_classification,
    :family,
    :bridge_family,
    :circuit_scope_class,
    :ordering_mode,
    :strict_dead_letter_family,
    :lifecycle_event
  ]

  @high_cardinality_metric_label_blocklist [
    :trace_id,
    :span_id,
    :parent_span_id,
    :request_id,
    :causation_id,
    :idempotency_key,
    :canonical_idempotency_key,
    :subject_id,
    :execution_id,
    :decision_id,
    :actor_id,
    :tenant_id,
    :installation_id,
    :boundary_ref,
    :trace_envelope_id,
    :route_id,
    :raw_provider_id,
    :prompt_hash,
    :artifact_hash,
    :payload_hash,
    :external_delivery_id,
    :connector_field,
    :provider_field
  ]

  @trace_attribute_allowlist [
    :trace_id,
    :span_id,
    :causation_id,
    :canonical_idempotency_key,
    :tenant_ref,
    :operation_family,
    :source_boundary,
    :safe_action,
    :error_class,
    :release_manifest_ref,
    :artifact_ref,
    :payload_hash,
    :overflow_counter_ref
  ]

  @trace_attribute_blocklist [
    :raw_payload,
    :payload_body,
    :provider_request,
    :provider_response,
    :prompt_body,
    :raw_webhook_body,
    :stdout,
    :stderr,
    :tenant_secret,
    :connector_payload
  ]

  @audit_event_admission_key [
    :tenant_or_partition,
    :owner_package,
    :source_boundary,
    :event_name,
    :error_class,
    :safe_action,
    :canonical_idempotency_key_or_payload_hash
  ]

  @hash_or_tokenize_fields [
    :idempotency_key,
    :subject_id,
    :execution_id,
    :decision_id,
    :actor_id,
    :tenant_id,
    :installation_id,
    :route_id,
    :provider_id,
    :prompt_hash,
    :artifact_hash,
    :payload_hash,
    :external_delivery_id
  ]

  @surface_sample_policies %{
    metric: :rate_limit_success,
    trace_span: :always_keep_fail_closed,
    trace_event: :always_keep_fail_closed,
    trace_export: :always_keep_fail_closed,
    audit_fact: :always_keep_security,
    audit_export: :always_keep_security,
    incident_export: :tail_sample_incident
  }

  @surface_overflow_actions %{
    metric: :sample_out,
    trace_span: :spill_to_artifact,
    trace_event: :spill_to_artifact,
    trace_export: :reject_export,
    audit_fact: :hash_value,
    audit_export: :reject_export,
    incident_export: :spill_to_artifact
  }

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec surfaces() :: [atom(), ...]
  def surfaces, do: @surfaces

  @spec profile_fields() :: [atom(), ...]
  def profile_fields, do: @profile_fields

  @spec sample_policies() :: [atom(), ...]
  def sample_policies, do: @sample_policies

  @spec overflow_safe_actions() :: [atom(), ...]
  def overflow_safe_actions, do: @overflow_safe_actions

  @spec low_cardinality_metric_label_allowlist() :: [atom(), ...]
  def low_cardinality_metric_label_allowlist, do: @low_cardinality_metric_label_allowlist

  @spec high_cardinality_metric_label_blocklist() :: [atom(), ...]
  def high_cardinality_metric_label_blocklist, do: @high_cardinality_metric_label_blocklist

  @spec profiles() :: %{required(atom()) => t()}
  def profiles, do: Map.new(@surfaces, &{&1, profile!(&1)})

  @spec profile!(atom() | String.t() | map() | keyword()) :: t()
  def profile!(surface) when is_atom(surface) or is_binary(surface) do
    surface
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

  @spec metric_label_allowed?(atom()) :: boolean()
  def metric_label_allowed?(label),
    do: label in @low_cardinality_metric_label_allowlist and not metric_label_blocked?(label)

  @spec metric_label_blocked?(atom()) :: boolean()
  def metric_label_blocked?(label), do: label in @high_cardinality_metric_label_blocklist

  @spec validate_metric_labels([atom()]) ::
          :ok | {:error, {:blocked_metric_labels | :unknown_metric_labels, [atom()]}}
  def validate_metric_labels(labels) when is_list(labels) do
    blocked = Enum.filter(labels, &metric_label_blocked?/1)
    unknown = Enum.reject(labels, &metric_label_allowed?/1)

    cond do
      blocked != [] -> {:error, {:blocked_metric_labels, blocked}}
      unknown != [] -> {:error, {:unknown_metric_labels, unknown}}
      true -> :ok
    end
  end

  defp default_attrs(surface) do
    surface = enum_atom!(surface, :observability_surface, @surfaces)

    %{
      contract_name: @contract_name,
      contract_version: @contract_version,
      observability_surface: surface,
      owner_repo: "citadel",
      owner_package: "core/observability_contract",
      event_name: "citadel.observability.cardinality_bounds.#{surface}",
      metric_label_allowlist: @low_cardinality_metric_label_allowlist,
      metric_label_blocklist: @high_cardinality_metric_label_blocklist,
      max_label_keys: 8,
      max_distinct_label_values_per_window: 128,
      label_window_ms: 60_000,
      trace_attribute_allowlist: @trace_attribute_allowlist,
      trace_attribute_blocklist: @trace_attribute_blocklist,
      max_attributes_per_span: 32,
      max_events_per_span: 64,
      max_attribute_key_bytes: 96,
      max_attribute_value_bytes: 1024,
      max_collection_items: 32,
      max_map_depth: 4,
      sample_policy: Map.fetch!(@surface_sample_policies, surface),
      sample_rate_or_budget: "success=100/min;debug=drop;protected=always",
      audit_amplification_guard_ref: "citadel.audit_amplification_guard.v1",
      audit_event_admission_key: @audit_event_admission_key,
      audit_event_window_ms: 60_000,
      max_audit_events_per_key_per_window: 1,
      audit_repeat_aggregation_ref: "citadel.audit_repeat_aggregation.v1",
      audit_overflow_counter_ref: "citadel.audit_overflow.count",
      redaction_policy_ref: "citadel.redaction.refs_only.v1",
      hash_or_tokenize_fields: @hash_or_tokenize_fields,
      spillover_artifact_policy: "spill-large-values-to-artifact-ref",
      overflow_safe_action: Map.fetch!(@surface_overflow_actions, surface),
      release_manifest_ref: "phase5-v7-milestone5"
    }
  end

  defp build!(attrs) do
    attrs = AttrMap.normalize!(attrs, @contract_name)
    metric_label_allowlist = required_atom_list!(attrs, :metric_label_allowlist)
    metric_label_blocklist = required_atom_list!(attrs, :metric_label_blocklist)
    trace_attribute_allowlist = required_atom_list!(attrs, :trace_attribute_allowlist)
    trace_attribute_blocklist = required_atom_list!(attrs, :trace_attribute_blocklist)

    ensure_default_blocklist!(:metric_label_blocklist, metric_label_blocklist)
    ensure_default_trace_blocklist!(trace_attribute_blocklist)
    ensure_disjoint!(:metric_label_allowlist, metric_label_allowlist, metric_label_blocklist)

    ensure_disjoint!(
      :trace_attribute_allowlist,
      trace_attribute_allowlist,
      trace_attribute_blocklist
    )

    %__MODULE__{
      contract_name:
        attrs
        |> AttrMap.get(:contract_name, @contract_name)
        |> literal!(@contract_name, :contract_name),
      contract_version:
        attrs
        |> AttrMap.get(:contract_version, @contract_version)
        |> literal!(@contract_version, :contract_version),
      observability_surface:
        attrs
        |> AttrMap.fetch!(:observability_surface, @contract_name)
        |> enum_atom!(:observability_surface, @surfaces),
      owner_repo: required_string!(attrs, :owner_repo),
      owner_package: required_string!(attrs, :owner_package),
      event_name: required_string!(attrs, :event_name),
      metric_label_allowlist: metric_label_allowlist,
      metric_label_blocklist: metric_label_blocklist,
      max_label_keys: positive_integer!(attrs, :max_label_keys),
      max_distinct_label_values_per_window:
        positive_integer!(attrs, :max_distinct_label_values_per_window),
      label_window_ms: positive_integer!(attrs, :label_window_ms),
      trace_attribute_allowlist: trace_attribute_allowlist,
      trace_attribute_blocklist: trace_attribute_blocklist,
      max_attributes_per_span: positive_integer!(attrs, :max_attributes_per_span),
      max_events_per_span: positive_integer!(attrs, :max_events_per_span),
      max_attribute_key_bytes: positive_integer!(attrs, :max_attribute_key_bytes),
      max_attribute_value_bytes: positive_integer!(attrs, :max_attribute_value_bytes),
      max_collection_items: positive_integer!(attrs, :max_collection_items),
      max_map_depth: positive_integer!(attrs, :max_map_depth),
      sample_policy:
        attrs
        |> AttrMap.fetch!(:sample_policy, @contract_name)
        |> enum_atom!(:sample_policy, @sample_policies),
      sample_rate_or_budget: required_string!(attrs, :sample_rate_or_budget),
      audit_amplification_guard_ref: required_string!(attrs, :audit_amplification_guard_ref),
      audit_event_admission_key: required_atom_list!(attrs, :audit_event_admission_key),
      audit_event_window_ms: positive_integer!(attrs, :audit_event_window_ms),
      max_audit_events_per_key_per_window:
        positive_integer!(attrs, :max_audit_events_per_key_per_window),
      audit_repeat_aggregation_ref: required_string!(attrs, :audit_repeat_aggregation_ref),
      audit_overflow_counter_ref: required_string!(attrs, :audit_overflow_counter_ref),
      redaction_policy_ref: required_string!(attrs, :redaction_policy_ref),
      hash_or_tokenize_fields: required_atom_list!(attrs, :hash_or_tokenize_fields),
      spillover_artifact_policy: required_string!(attrs, :spillover_artifact_policy),
      overflow_safe_action:
        attrs
        |> AttrMap.fetch!(:overflow_safe_action, @contract_name)
        |> enum_atom!(:overflow_safe_action, @overflow_safe_actions),
      release_manifest_ref: required_string!(attrs, :release_manifest_ref)
    }
  end

  defp normalize(%__MODULE__{} = profile) do
    {:ok, profile |> dump() |> build!()}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp ensure_default_blocklist!(field, values) do
    missing = @high_cardinality_metric_label_blocklist -- values

    if missing != [] do
      raise ArgumentError,
            "#{@contract_name}.#{field} must include high-cardinality metric labels: " <>
              inspect(missing)
    end
  end

  defp ensure_default_trace_blocklist!(values) do
    missing = @trace_attribute_blocklist -- values

    if missing != [] do
      raise ArgumentError,
            "#{@contract_name}.trace_attribute_blocklist must include raw payload fields: " <>
              inspect(missing)
    end
  end

  defp ensure_disjoint!(field, left, right) do
    overlap =
      left
      |> MapSet.new()
      |> MapSet.intersection(MapSet.new(right))
      |> MapSet.to_list()

    if overlap != [] do
      raise ArgumentError,
            "#{@contract_name}.#{field} overlaps with its blocklist: #{inspect(overlap)}"
    end
  end

  defp required_atom_list!(attrs, key) do
    attrs
    |> AttrMap.fetch!(key, @contract_name)
    |> atom_list!(key)
  end

  defp atom_list!(values, key) when is_list(values) and values != [] do
    Enum.map(values, fn
      value when is_atom(value) ->
        value

      value ->
        raise ArgumentError, "#{@contract_name}.#{key} must contain atoms, got #{inspect(value)}"
    end)
    |> uniq!(key)
  end

  defp atom_list!(value, key) do
    raise ArgumentError,
          "#{@contract_name}.#{key} must be a non-empty atom list, got #{inspect(value)}"
  end

  defp uniq!(values, key) do
    if Enum.uniq(values) == values do
      values
    else
      raise ArgumentError, "#{@contract_name}.#{key} must not contain duplicate values"
    end
  end

  defp positive_integer!(attrs, key) do
    value = AttrMap.fetch!(attrs, key, @contract_name)

    if is_integer(value) and value > 0 do
      value
    else
      raise ArgumentError, "#{@contract_name}.#{key} must be a positive integer"
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
