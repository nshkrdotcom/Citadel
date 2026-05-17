defmodule Citadel.ConnectorBinding.CredentialLease do
  @moduledoc """
  Generic credential lease materialization value.

  This module validates refs and scopes for generic binding kinds. It does not
  select providers or inspect provider families as control flow.
  """

  alias Citadel.ContractCore.Value

  @binding_kinds [:source, :source_publication, :runtime, :tool, :evidence, :resource_effect]
  @operation_classes [
    :source_read,
    :source_write,
    :runtime_session,
    :runtime_tool_invocation,
    :evidence_collection,
    :resource_effect,
    :lower_read,
    :trace_replay,
    :review_decision
  ]

  @fields [
    :tenant_ref,
    :installation_ref,
    :binding_ref,
    :credential_scope_ref,
    :connector_binding_ref,
    :credential_handle_ref,
    :credential_lease_ref,
    :operation_class,
    :required_scopes,
    :issued_at,
    :expires_at,
    :metadata
  ]

  @forbidden_material [
    :api_key,
    :auth_json,
    :authorization_header,
    :default_client,
    :env,
    :home_path,
    :native_auth_file,
    :provider_payload,
    :raw_secret,
    :raw_token,
    :refresh_token,
    :singleton_client,
    :target_credentials,
    :token,
    :token_file
  ]

  @enforce_keys [
    :tenant_ref,
    :installation_ref,
    :binding_ref,
    :binding_kind,
    :credential_scope_ref,
    :connector_binding_ref,
    :credential_handle_ref,
    :credential_lease_ref,
    :operation_class,
    :required_scopes,
    :issued_at,
    :expires_at,
    :raw_material_present?
  ]
  defstruct @enforce_keys ++ [metadata: %{}]

  @type t :: %__MODULE__{}

  @spec binding_kinds() :: [atom()]
  def binding_kinds, do: @binding_kinds

  @spec materialize(atom() | String.t(), map() | keyword(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def materialize(binding_kind, attrs, opts \\ []) when is_map(attrs) or is_list(attrs) do
    attrs =
      Value.normalize_attrs!(
        attrs,
        "Citadel.CredentialLease",
        @fields ++ @forbidden_material
      )

    with {:ok, kind} <- normalize_binding_kind(binding_kind),
         :ok <- reject_material(attrs),
         {:ok, lease} <- build_lease(kind, attrs),
         :ok <- validate_expected_scope(lease, opts),
         :ok <- validate_required_scopes(lease, opts),
         :ok <- validate_time_window(lease) do
      {:ok, lease}
    end
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp build_lease(binding_kind, attrs) do
    {:ok,
     struct!(__MODULE__, %{
       tenant_ref: required_string(attrs, :tenant_ref),
       installation_ref: required_string(attrs, :installation_ref),
       binding_ref: required_string(attrs, :binding_ref),
       binding_kind: binding_kind,
       credential_scope_ref: required_string(attrs, :credential_scope_ref),
       connector_binding_ref: required_string(attrs, :connector_binding_ref),
       credential_handle_ref: required_string(attrs, :credential_handle_ref),
       credential_lease_ref: required_string(attrs, :credential_lease_ref),
       operation_class:
         Value.required(attrs, :operation_class, "Citadel.CredentialLease", fn value ->
           Value.enum!(value, @operation_classes, "Citadel.CredentialLease.operation_class")
         end),
       required_scopes:
         Value.optional(
           attrs,
           :required_scopes,
           "Citadel.CredentialLease",
           &Value.unique_strings!(&1, "Citadel.CredentialLease.required_scopes"),
           []
         ),
       issued_at:
         Value.required(attrs, :issued_at, "Citadel.CredentialLease", fn value ->
           Value.datetime!(value, "Citadel.CredentialLease.issued_at")
         end),
       expires_at:
         Value.required(attrs, :expires_at, "Citadel.CredentialLease", fn value ->
           Value.datetime!(value, "Citadel.CredentialLease.expires_at")
         end),
       raw_material_present?: false,
       metadata:
         Value.optional(
           attrs,
           :metadata,
           "Citadel.CredentialLease",
           &Value.json_object!(&1, "Citadel.CredentialLease.metadata"),
           %{}
         )
     })}
  end

  defp normalize_binding_kind(kind) when is_atom(kind) do
    if kind in @binding_kinds do
      {:ok, kind}
    else
      {:error, {:unsupported_binding_kind, kind}}
    end
  end

  defp normalize_binding_kind(kind) when is_binary(kind) do
    case Enum.find(@binding_kinds, &(Atom.to_string(&1) == kind)) do
      nil -> {:error, {:unsupported_binding_kind, kind}}
      normalized -> {:ok, normalized}
    end
  end

  defp reject_material(attrs) do
    present = Enum.filter(@forbidden_material, &Map.has_key?(attrs, Atom.to_string(&1)))

    case present do
      [] -> :ok
      fields -> {:error, {:raw_credential_material, fields}}
    end
  end

  defp validate_expected_scope(lease, opts) do
    case Keyword.get(opts, :expected_credential_scope_ref) do
      nil ->
        :ok

      expected when expected == lease.credential_scope_ref ->
        :ok

      _other ->
        {:error, {:credential_scope_mismatch, [:credential_scope_ref]}}
    end
  end

  defp validate_required_scopes(lease, opts) do
    case Keyword.get(opts, :allowed_required_scopes, :any) do
      :any ->
        :ok

      allowed ->
        invalid = Enum.reject(lease.required_scopes, &(&1 in allowed))

        case invalid do
          [] -> :ok
          scopes -> {:error, {:required_scope_not_allowed, scopes}}
        end
    end
  end

  defp validate_time_window(lease) do
    case DateTime.compare(lease.expires_at, lease.issued_at) do
      :gt -> :ok
      _other -> {:error, :credential_lease_not_fresh}
    end
  end

  defp required_string(attrs, field) do
    Value.required(attrs, field, "Citadel.CredentialLease", fn value ->
      Value.string!(value, "Citadel.CredentialLease.#{field}")
    end)
  end
end
