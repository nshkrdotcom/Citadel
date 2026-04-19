defmodule Citadel.AuthorityContract.OperatorRecoveryAction.V1 do
  @moduledoc """
  Authorized operator recovery action envelope for Phase 4 control paths.
  """

  alias Citadel.ContractCore.AttrMap
  alias Citadel.ContractCore.CanonicalJson

  @contract_name "Citadel.OperatorRecoveryAction.v1"
  @contract_version "1.0.0"
  @safe_action_classes [
    :inspect_only,
    :retry_with_authority,
    :cancel_workflow,
    :pause_workflow,
    :resume_workflow,
    :retry_workflow,
    :replan_workflow,
    :quarantine_subject,
    :reconcile_projection
  ]

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
    :operator_ref,
    :action_ref,
    :target_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :safe_action_class,
    :approval_ref,
    :operator_reason,
    :audit_ref,
    :requested_at,
    :metadata
  ]

  @enforce_keys @fields -- [:principal_ref, :system_actor_ref]
  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec safe_action_classes() :: [atom()]
  def safe_action_classes, do: @safe_action_classes

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = action), do: normalize(action)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = action) do
    case normalize(action) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = action), do: Map.new(@fields, &{&1, Map.fetch!(action, &1)})

  defp build!(attrs) do
    attrs = AttrMap.normalize!(attrs, "#{@contract_name} attrs")
    principal_ref = optional_ref(attrs, :principal_ref)
    system_actor_ref = optional_ref(attrs, :system_actor_ref)
    validate_actor_pair!(principal_ref, system_actor_ref)

    %__MODULE__{
      contract_name:
        attrs
        |> AttrMap.fetch!(:contract_name, @contract_name)
        |> literal!(@contract_name, :contract_name),
      contract_version:
        attrs
        |> AttrMap.fetch!(:contract_version, @contract_name)
        |> literal!(@contract_version, :contract_version),
      tenant_ref: attrs |> AttrMap.fetch!(:tenant_ref, @contract_name) |> ref!(:tenant_ref),
      installation_ref:
        attrs |> AttrMap.fetch!(:installation_ref, @contract_name) |> ref!(:installation_ref),
      workspace_ref:
        attrs |> AttrMap.fetch!(:workspace_ref, @contract_name) |> ref!(:workspace_ref),
      project_ref: attrs |> AttrMap.fetch!(:project_ref, @contract_name) |> ref!(:project_ref),
      environment_ref:
        attrs |> AttrMap.fetch!(:environment_ref, @contract_name) |> ref!(:environment_ref),
      principal_ref: principal_ref,
      system_actor_ref: system_actor_ref,
      operator_ref: attrs |> AttrMap.fetch!(:operator_ref, @contract_name) |> ref!(:operator_ref),
      action_ref: attrs |> AttrMap.fetch!(:action_ref, @contract_name) |> string!(:action_ref),
      target_ref: attrs |> AttrMap.fetch!(:target_ref, @contract_name) |> ref!(:target_ref),
      resource_ref: attrs |> AttrMap.fetch!(:resource_ref, @contract_name) |> ref!(:resource_ref),
      authority_packet_ref:
        attrs
        |> AttrMap.fetch!(:authority_packet_ref, @contract_name)
        |> string!(:authority_packet_ref),
      permission_decision_ref:
        attrs
        |> AttrMap.fetch!(:permission_decision_ref, @contract_name)
        |> string!(:permission_decision_ref),
      idempotency_key:
        attrs |> AttrMap.fetch!(:idempotency_key, @contract_name) |> string!(:idempotency_key),
      trace_id: attrs |> AttrMap.fetch!(:trace_id, @contract_name) |> string!(:trace_id),
      correlation_id:
        attrs |> AttrMap.fetch!(:correlation_id, @contract_name) |> string!(:correlation_id),
      release_manifest_ref:
        attrs
        |> AttrMap.fetch!(:release_manifest_ref, @contract_name)
        |> string!(:release_manifest_ref),
      safe_action_class:
        attrs
        |> AttrMap.fetch!(:safe_action_class, @contract_name)
        |> enum!(@safe_action_classes, :safe_action_class),
      approval_ref:
        attrs |> AttrMap.fetch!(:approval_ref, @contract_name) |> string!(:approval_ref),
      operator_reason:
        attrs |> AttrMap.fetch!(:operator_reason, @contract_name) |> string!(:operator_reason),
      audit_ref: attrs |> AttrMap.fetch!(:audit_ref, @contract_name) |> string!(:audit_ref),
      requested_at:
        attrs |> AttrMap.fetch!(:requested_at, @contract_name) |> timestamp!(:requested_at),
      metadata: attrs |> AttrMap.fetch!(:metadata, @contract_name) |> json_object!(:metadata)
    }
  end

  defp normalize(%__MODULE__{} = action) do
    {:ok, action |> dump() |> build!()}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp optional_ref(attrs, key) do
    case AttrMap.get(attrs, key) do
      nil -> nil
      value -> ref!(value, key)
    end
  end

  defp validate_actor_pair!(nil, nil),
    do: raise(ArgumentError, "#{@contract_name} requires principal_ref or system_actor_ref")

  defp validate_actor_pair!(_principal_ref, _system_actor_ref), do: :ok

  defp literal!(value, expected, _field) when value == expected, do: value

  defp literal!(value, expected, field),
    do:
      raise(
        ArgumentError,
        "#{@contract_name}.#{field} must be #{expected}, got: #{inspect(value)}"
      )

  defp ref!(value, field) when is_binary(value), do: string!(value, field)

  defp ref!(value, field) do
    normalized = CanonicalJson.normalize!(value)

    unless is_map(normalized) do
      raise ArgumentError, "#{@contract_name}.#{field} must be a non-empty string or JSON object"
    end

    normalized
  end

  defp string!(value, field) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "#{@contract_name}.#{field} must be a non-empty string"
    end

    value
  end

  defp string!(value, field),
    do:
      raise(
        ArgumentError,
        "#{@contract_name}.#{field} must be a non-empty string, got: #{inspect(value)}"
      )

  defp enum!(value, allowed, field) when is_binary(value) do
    Enum.find(allowed, &(Atom.to_string(&1) == value))
    |> enum!(allowed, field)
  end

  defp enum!(value, allowed, field) when is_atom(value) do
    if value in allowed do
      value
    else
      enum_error!(value, allowed, field)
    end
  end

  defp enum!(value, allowed, field), do: enum_error!(value, allowed, field)

  defp enum_error!(value, allowed, field) do
    raise ArgumentError,
          "#{@contract_name}.#{field} must be one of #{inspect(allowed)}, got: #{inspect(value)}"
  end

  defp timestamp!(%DateTime{} = value, _field), do: DateTime.to_iso8601(value)

  defp timestamp!(value, field) when is_binary(value), do: string!(value, field)

  defp timestamp!(value, field),
    do:
      raise(
        ArgumentError,
        "#{@contract_name}.#{field} must be an ISO-8601 timestamp string, got: #{inspect(value)}"
      )

  defp json_object!(value, field) do
    normalized = CanonicalJson.normalize!(value)

    unless is_map(normalized) do
      raise ArgumentError, "#{@contract_name}.#{field} must normalize to a JSON object"
    end

    normalized
  end
end
