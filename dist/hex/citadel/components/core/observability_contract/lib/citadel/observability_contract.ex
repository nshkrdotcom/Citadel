defmodule Citadel.ObservabilityContract do
  @moduledoc """
  Packet-aligned ownership surface for `core/observability_contract`.
  """

  @manifest %{
    package: :citadel_observability_contract,
    layer: :core,
    status: :wave_5_contract_frozen,
    owns: [
      :trace_vocabulary,
      :telemetry_names,
      :metadata_conventions,
      :platform_audit_hash_chain_v1,
      :observability_cardinality_bounds_v1
    ],
    internal_dependencies: [:citadel_contract_core],
    external_dependencies: []
  }

  @spec telemetry_prefix() :: [atom()]
  def telemetry_prefix, do: [:citadel]

  @spec trace_record_kinds() :: [atom(), ...]
  def trace_record_kinds, do: Citadel.ObservabilityContract.Trace.record_kinds()

  @spec trace_required_event_families() :: [String.t(), ...]
  def trace_required_event_families,
    do: Citadel.ObservabilityContract.Trace.required_event_families()

  @spec trace_protected_error_families() :: [String.t(), ...]
  def trace_protected_error_families,
    do: Citadel.ObservabilityContract.Trace.protected_error_families()

  @spec trace_required_correlation_keys() :: [atom(), ...]
  def trace_required_correlation_keys,
    do: Citadel.ObservabilityContract.Trace.required_correlation_keys()

  @spec trace_failure_reason_codes() :: [atom(), ...]
  def trace_failure_reason_codes, do: Citadel.ObservabilityContract.Trace.failure_reason_codes()

  @spec cardinality_bounds_module() :: module()
  def cardinality_bounds_module, do: Citadel.ObservabilityContract.CardinalityBounds

  @spec cardinality_bounds_surfaces() :: [atom(), ...]
  def cardinality_bounds_surfaces, do: Citadel.ObservabilityContract.CardinalityBounds.surfaces()

  @spec cardinality_bounds_profile_fields() :: [atom(), ...]
  def cardinality_bounds_profile_fields,
    do: Citadel.ObservabilityContract.CardinalityBounds.profile_fields()

  @spec cardinality_bounds_profiles() :: %{required(atom()) => struct()}
  def cardinality_bounds_profiles, do: Citadel.ObservabilityContract.CardinalityBounds.profiles()

  @spec cardinality_bounds_profile!(atom() | String.t()) :: struct()
  def cardinality_bounds_profile!(surface),
    do: Citadel.ObservabilityContract.CardinalityBounds.profile!(surface)

  @spec telemetry_definitions() :: map()
  def telemetry_definitions, do: Citadel.ObservabilityContract.Telemetry.definitions()

  @spec telemetry_event_name(atom()) :: [atom(), ...]
  def telemetry_event_name(name), do: Citadel.ObservabilityContract.Telemetry.event_name(name)

  @spec telemetry_measurement_keys(atom()) :: [atom(), ...]
  def telemetry_measurement_keys(name),
    do: Citadel.ObservabilityContract.Telemetry.measurement_keys(name)

  @spec telemetry_metadata_keys(atom()) :: [atom(), ...]
  def telemetry_metadata_keys(name),
    do: Citadel.ObservabilityContract.Telemetry.metadata_keys(name)

  @spec audit_hash_chain_module() :: module()
  def audit_hash_chain_module, do: Citadel.ObservabilityContract.AuditHashChain.V1

  @spec manifest() :: map()
  def manifest, do: @manifest
end
