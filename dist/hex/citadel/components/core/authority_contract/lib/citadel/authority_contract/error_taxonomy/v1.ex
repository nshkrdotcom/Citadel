defmodule Citadel.AuthorityContract.ErrorTaxonomy.V1 do
  @moduledoc """
  Platform error taxonomy entry for public and operator-visible failure paths.

  Contract: `Platform.ErrorTaxonomy.v1`.
  """

  alias Citadel.AuthorityContract.PlatformContractSupport, as: Support
  alias Citadel.ContractCore.AttrMap

  @contract_name "Platform.ErrorTaxonomy.v1"
  @contract_version "1.0.0"
  @error_classes [
    :auth_error,
    :validation_error,
    :policy_error,
    :tenant_scope_error,
    :semantic_failure,
    :runtime_error,
    :resource_pressure
  ]
  @retry_postures [
    :never,
    :safe_idempotent,
    :after_input_change,
    :after_operator_action,
    :after_backoff,
    :after_redecision,
    :manual_operator
  ]
  @redaction_classes [:public_safe, :operator_summary, :operator_full, :tenant_sensitive, :secret]

  @fields [
    :contract_name,
    :contract_version,
    :error_taxonomy_id,
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
    :owner_repo,
    :producer_ref,
    :consumer_ref,
    :error_code,
    :error_class,
    :retry_posture,
    :operator_safe_action,
    :safe_action_code,
    :redaction_class,
    :runbook_path,
    :message,
    :details,
    :redaction
  ]

  @enforce_keys @fields -- [:principal_ref, :system_actor_ref]
  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec error_classes() :: [atom()]
  def error_classes, do: @error_classes

  @spec retry_postures() :: [atom()]
  def retry_postures, do: @retry_postures

  @spec redaction_classes() :: [atom()]
  def redaction_classes, do: @redaction_classes

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = taxonomy), do: normalize(taxonomy)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = taxonomy) do
    case normalize(taxonomy) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = taxonomy) do
    @fields
    |> Map.new(&{&1, Map.fetch!(taxonomy, &1)})
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp build!(attrs) do
    attrs = Support.normalize_attrs!(attrs, @contract_name)
    {principal_ref, system_actor_ref} = Support.actor_refs!(attrs, @contract_name)
    operator_safe_action = Support.required_string!(attrs, :operator_safe_action, @contract_name)
    safe_action_code = Support.required_string!(attrs, :safe_action_code, @contract_name)
    validate_safe_action_match!(operator_safe_action, safe_action_code)

    %__MODULE__{
      contract_name:
        attrs
        |> Support.required_string!(:contract_name, @contract_name)
        |> Support.literal!(@contract_name, :contract_name, @contract_name),
      contract_version:
        attrs
        |> Support.required_string!(:contract_version, @contract_name)
        |> Support.literal!(@contract_version, :contract_version, @contract_name),
      error_taxonomy_id: Support.required_string!(attrs, :error_taxonomy_id, @contract_name),
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
      owner_repo: Support.required_string!(attrs, :owner_repo, @contract_name),
      producer_ref: Support.required_string!(attrs, :producer_ref, @contract_name),
      consumer_ref: Support.required_string!(attrs, :consumer_ref, @contract_name),
      error_code: Support.required_string!(attrs, :error_code, @contract_name),
      error_class:
        attrs
        |> AttrMap.fetch!(:error_class, @contract_name)
        |> Support.enum_atomish!(@error_classes, :error_class, @contract_name),
      retry_posture:
        attrs
        |> AttrMap.fetch!(:retry_posture, @contract_name)
        |> Support.enum_atomish!(@retry_postures, :retry_posture, @contract_name),
      operator_safe_action: operator_safe_action,
      safe_action_code: safe_action_code,
      redaction_class:
        attrs
        |> AttrMap.fetch!(:redaction_class, @contract_name)
        |> Support.enum_atomish!(@redaction_classes, :redaction_class, @contract_name),
      runbook_path: Support.required_string!(attrs, :runbook_path, @contract_name),
      message: Support.required_string!(attrs, :message, @contract_name),
      details: Support.json_object!(attrs, :details, @contract_name),
      redaction: Support.json_object!(attrs, :redaction, @contract_name)
    }
  end

  defp normalize(%__MODULE__{} = taxonomy) do
    {:ok, taxonomy |> dump() |> build!()}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp validate_safe_action_match!(operator_safe_action, safe_action_code)
       when operator_safe_action == safe_action_code,
       do: :ok

  defp validate_safe_action_match!(operator_safe_action, safe_action_code) do
    raise ArgumentError,
          "#{@contract_name}.safe_action_code must match operator_safe_action, got: " <>
            "#{inspect(safe_action_code)} != #{inspect(operator_safe_action)}"
  end
end
