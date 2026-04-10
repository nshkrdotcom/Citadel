defmodule Citadel.InvocationBridge do
  @moduledoc """
  Packet-aligned ownership surface for `bridges/invocation_bridge`.
  """

  alias Citadel.InvocationRequest

  @manifest %{
    package: :citadel_invocation_bridge,
    layer: :bridge,
    status: :wave_2_seam_frozen,
    owns: [:invocation_handoff, :lower_seam_alignment, :request_projection],
    internal_dependencies: [
      :citadel_core,
      :citadel_runtime,
      :citadel_authority_contract,
      :citadel_observability_contract
    ],
    external_dependencies: [:jido_integration_v2_contracts]
  }

  @spec shared_contract_strategy() :: :citadel_invocation_request_entrypoint
  def shared_contract_strategy, do: :citadel_invocation_request_entrypoint

  @spec supported_invocation_request_schema_versions() :: [pos_integer(), ...]
  def supported_invocation_request_schema_versions, do: [InvocationRequest.schema_version()]

  @spec ensure_supported_invocation_request_schema_version!(integer()) :: integer()
  def ensure_supported_invocation_request_schema_version!(schema_version) do
    if schema_version in supported_invocation_request_schema_versions() do
      schema_version
    else
      raise ArgumentError,
            "unsupported Citadel.InvocationRequest.schema_version: #{inspect(schema_version)}"
    end
  end

  @spec manifest() :: map()
  def manifest, do: @manifest
end
