defmodule Citadel.AuthorityContract.InstallationRevisionEpoch.V1 do
  @moduledoc """
  Platform revision and activation-epoch fence evidence.

  Contract: `Platform.InstallationRevisionEpoch.v1`.
  """

  alias Citadel.ContractCore.AttrMap
  alias Citadel.AuthorityContract.PlatformContractSupport, as: Support

  @contract_name "Platform.InstallationRevisionEpoch.v1"
  @contract_version "1.0.0"
  @fence_statuses [:accepted, :rejected]

  @fields [
    :contract_name,
    :contract_version,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :installation_revision,
    :activation_epoch,
    :lease_epoch,
    :node_id,
    :fence_decision_ref,
    :fence_status,
    :stale_reason,
    :attempted_installation_revision,
    :attempted_activation_epoch,
    :attempted_lease_epoch,
    :mixed_revision_node_ref,
    :rollout_window_ref
  ]

  @enforce_keys @fields --
                  [
                    :principal_ref,
                    :system_actor_ref,
                    :attempted_installation_revision,
                    :attempted_activation_epoch,
                    :attempted_lease_epoch,
                    :mixed_revision_node_ref,
                    :rollout_window_ref
                  ]
  defstruct @fields

  @type fence_status :: :accepted | :rejected
  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec fence_statuses() :: [fence_status()]
  def fence_statuses, do: @fence_statuses

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = fence), do: normalize(fence)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = fence) do
    case normalize(fence) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = fence) do
    @fields
    |> Map.new(&{&1, Map.fetch!(fence, &1)})
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp build!(attrs) do
    attrs = Support.normalize_attrs!(attrs, @contract_name)
    {principal_ref, system_actor_ref} = Support.actor_refs!(attrs, @contract_name)

    fence =
      %__MODULE__{
        contract_name:
          attrs
          |> AttrMap.get(:contract_name, @contract_name)
          |> Support.literal!(@contract_name, :contract_name, @contract_name),
        contract_version:
          attrs
          |> AttrMap.get(:contract_version, @contract_version)
          |> Support.literal!(@contract_version, :contract_version, @contract_name),
        tenant_ref: Support.required_string!(attrs, :tenant_ref, @contract_name),
        installation_ref: Support.required_string!(attrs, :installation_ref, @contract_name),
        workspace_ref: Support.required_string!(attrs, :workspace_ref, @contract_name),
        project_ref: Support.required_string!(attrs, :project_ref, @contract_name),
        environment_ref: Support.required_string!(attrs, :environment_ref, @contract_name),
        principal_ref: principal_ref,
        system_actor_ref: system_actor_ref,
        resource_ref: Support.required_string!(attrs, :resource_ref, @contract_name),
        authority_packet_ref:
          Support.required_string!(attrs, :authority_packet_ref, @contract_name),
        permission_decision_ref:
          Support.required_string!(attrs, :permission_decision_ref, @contract_name),
        idempotency_key: Support.required_string!(attrs, :idempotency_key, @contract_name),
        trace_id: Support.required_string!(attrs, :trace_id, @contract_name),
        correlation_id: Support.required_string!(attrs, :correlation_id, @contract_name),
        release_manifest_ref:
          Support.required_string!(attrs, :release_manifest_ref, @contract_name),
        installation_revision:
          Support.required_non_neg_integer!(attrs, :installation_revision, @contract_name),
        activation_epoch:
          Support.required_non_neg_integer!(attrs, :activation_epoch, @contract_name),
        lease_epoch: Support.required_non_neg_integer!(attrs, :lease_epoch, @contract_name),
        node_id: Support.required_string!(attrs, :node_id, @contract_name),
        fence_decision_ref: Support.required_string!(attrs, :fence_decision_ref, @contract_name),
        fence_status:
          attrs
          |> AttrMap.fetch!(:fence_status, @contract_name)
          |> Support.enum_atomish!(@fence_statuses, :fence_status, @contract_name),
        stale_reason: Support.required_string!(attrs, :stale_reason, @contract_name),
        attempted_installation_revision:
          Support.optional_non_neg_integer!(
            attrs,
            :attempted_installation_revision,
            @contract_name
          ),
        attempted_activation_epoch:
          Support.optional_non_neg_integer!(attrs, :attempted_activation_epoch, @contract_name),
        attempted_lease_epoch:
          Support.optional_non_neg_integer!(attrs, :attempted_lease_epoch, @contract_name),
        mixed_revision_node_ref:
          Support.optional_string!(attrs, :mixed_revision_node_ref, @contract_name),
        rollout_window_ref: Support.optional_string!(attrs, :rollout_window_ref, @contract_name)
      }

    validate_fence_semantics!(fence)
  end

  defp normalize(%__MODULE__{} = fence) do
    {:ok, fence |> dump() |> build!()}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp validate_fence_semantics!(%__MODULE__{fence_status: :accepted} = fence) do
    if fence.stale_reason != "none" do
      raise ArgumentError, "#{@contract_name} accepted fences must use stale_reason none"
    end

    if attempted_drift?(fence) do
      raise ArgumentError, "#{@contract_name} accepted fences cannot carry stale attempted values"
    end

    fence
  end

  defp validate_fence_semantics!(%__MODULE__{fence_status: :rejected} = fence) do
    if fence.stale_reason == "none" or not stale_attempt?(fence) do
      raise ArgumentError, "#{@contract_name} rejected fences require stale attempted evidence"
    end

    fence
  end

  defp attempted_drift?(fence) do
    Enum.any?(
      [
        {fence.attempted_installation_revision, fence.installation_revision},
        {fence.attempted_activation_epoch, fence.activation_epoch},
        {fence.attempted_lease_epoch, fence.lease_epoch}
      ],
      fn
        {nil, _current} -> false
        {attempted, current} -> attempted != current
      end
    )
  end

  defp stale_attempt?(fence) do
    Enum.any?(
      [
        {fence.attempted_installation_revision, fence.installation_revision},
        {fence.attempted_activation_epoch, fence.activation_epoch},
        {fence.attempted_lease_epoch, fence.lease_epoch}
      ],
      fn
        {nil, _current} -> false
        {attempted, current} -> attempted < current
      end
    )
  end
end
