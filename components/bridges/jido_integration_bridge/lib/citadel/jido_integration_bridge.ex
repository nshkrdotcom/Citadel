defmodule Citadel.JidoIntegrationBridge do
  @moduledoc """
  Citadel-owned transport seam for Brain-to-Spine durable submission.
  """

  alias Jido.Integration.V2.BrainInvocation
  alias Jido.Integration.V2.SubmissionAcceptance
  alias Jido.Integration.V2.SubmissionRejection

  @transport_env_key :transport_module

  defmodule Transport do
    @moduledoc false

    alias Jido.Integration.V2.BrainInvocation
    alias Jido.Integration.V2.SubmissionAcceptance
    alias Jido.Integration.V2.SubmissionRejection

    @callback submit_brain_invocation(BrainInvocation.t()) ::
                {:accepted, SubmissionAcceptance.t()}
                | {:rejected, SubmissionRejection.t()}
                | {:error, atom()}
  end

  defmodule NoopTransport do
    @moduledoc false

    @behaviour Transport

    @impl true
    def submit_brain_invocation(%BrainInvocation{}), do: {:error, :transport_not_configured}
  end

  @manifest %{
    package: :citadel_jido_integration_bridge,
    layer: :bridge,
    status: :durable_submission_contract_frozen,
    owns: [:brain_invocation_projection, :shared_lineage_coercion, :transport_configuration],
    internal_dependencies: [
      :citadel_core,
      :citadel_authority_contract,
      :citadel_execution_governance_contract,
      :citadel_invocation_bridge
    ],
    external_dependencies: [:jido_integration_v2_contracts]
  }

  @spec manifest() :: map()
  def manifest, do: @manifest

  @spec transport_module() :: module()
  def transport_module do
    Application.get_env(:citadel_jido_integration_bridge, @transport_env_key, NoopTransport)
  end

  @spec put_transport_module(module()) :: :ok
  def put_transport_module(module) when is_atom(module) do
    Application.put_env(:citadel_jido_integration_bridge, @transport_env_key, module)
  end
end
