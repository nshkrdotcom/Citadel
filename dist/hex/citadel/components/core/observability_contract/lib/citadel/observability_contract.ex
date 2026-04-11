defmodule Citadel.ObservabilityContract do
  @moduledoc """
  Packet-aligned ownership surface for `core/observability_contract`.
  """

  @manifest %{
    package: :citadel_observability_contract,
    layer: :core,
    status: :wave_5_contract_frozen,
    owns: [:trace_vocabulary, :telemetry_names, :metadata_conventions],
    internal_dependencies: [:citadel_contract_core],
    external_dependencies: []
  }

  @spec telemetry_prefix() :: [atom()]
  def telemetry_prefix, do: [:citadel]

  @spec trace_record_kinds() :: [atom(), ...]
  def trace_record_kinds, do: Citadel.ObservabilityContract.Trace.record_kinds()

  @spec trace_required_event_families() :: [String.t(), ...]
  def trace_required_event_families, do: Citadel.ObservabilityContract.Trace.required_event_families()

  @spec trace_protected_error_families() :: [String.t(), ...]
  def trace_protected_error_families,
    do: Citadel.ObservabilityContract.Trace.protected_error_families()

  @spec trace_required_correlation_keys() :: [atom(), ...]
  def trace_required_correlation_keys,
    do: Citadel.ObservabilityContract.Trace.required_correlation_keys()

  @spec trace_failure_reason_codes() :: [atom(), ...]
  def trace_failure_reason_codes, do: Citadel.ObservabilityContract.Trace.failure_reason_codes()

  @spec telemetry_definitions() :: map()
  def telemetry_definitions, do: Citadel.ObservabilityContract.Telemetry.definitions()

  @spec telemetry_event_name(atom()) :: [atom(), ...]
  def telemetry_event_name(name), do: Citadel.ObservabilityContract.Telemetry.event_name(name)

  @spec telemetry_measurement_keys(atom()) :: [atom(), ...]
  def telemetry_measurement_keys(name),
    do: Citadel.ObservabilityContract.Telemetry.measurement_keys(name)

  @spec telemetry_metadata_keys(atom()) :: [atom(), ...]
  def telemetry_metadata_keys(name), do: Citadel.ObservabilityContract.Telemetry.metadata_keys(name)

  @spec manifest() :: map()
  def manifest, do: @manifest
end
