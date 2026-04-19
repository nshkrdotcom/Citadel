defmodule Citadel.AuthorityContract.LeaseRevocation.V1 do
  @moduledoc """
  Platform lease revocation and propagation evidence.

  Contract: `Platform.LeaseRevocation.v1`.
  """

  alias Citadel.ContractCore.AttrMap
  alias Citadel.AuthorityContract.PlatformContractSupport, as: Support

  @contract_name "Platform.LeaseRevocation.v1"
  @contract_version "1.0.0"
  @lease_statuses [:revoked, :rejected_after_revocation]

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
    :lease_ref,
    :revocation_ref,
    :revoked_at,
    :lease_scope,
    :cache_invalidation_ref,
    :post_revocation_attempt_ref,
    :lease_status
  ]

  @enforce_keys @fields -- [:principal_ref, :system_actor_ref]
  defstruct @fields

  @type lease_status :: :revoked | :rejected_after_revocation
  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec lease_statuses() :: [lease_status()]
  def lease_statuses, do: @lease_statuses

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = revocation), do: normalize(revocation)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = revocation) do
    case normalize(revocation) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = revocation) do
    @fields
    |> Map.new(&{&1, Map.fetch!(revocation, &1)})
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp build!(attrs) do
    attrs = Support.normalize_attrs!(attrs, @contract_name)
    {principal_ref, system_actor_ref} = Support.actor_refs!(attrs, @contract_name)

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
      lease_ref: Support.required_string!(attrs, :lease_ref, @contract_name),
      revocation_ref: Support.required_string!(attrs, :revocation_ref, @contract_name),
      revoked_at: Support.required_datetime!(attrs, :revoked_at, @contract_name),
      lease_scope: Support.non_empty_json_object!(attrs, :lease_scope, @contract_name),
      cache_invalidation_ref:
        Support.required_string!(attrs, :cache_invalidation_ref, @contract_name),
      post_revocation_attempt_ref:
        Support.required_string!(attrs, :post_revocation_attempt_ref, @contract_name),
      lease_status:
        attrs
        |> AttrMap.get(:lease_status, :revoked)
        |> Support.enum_atomish!(@lease_statuses, :lease_status, @contract_name)
    }
  end

  defp normalize(%__MODULE__{} = revocation) do
    {:ok, revocation |> dump() |> build!()}
  rescue
    error in ArgumentError -> {:error, error}
  end
end
