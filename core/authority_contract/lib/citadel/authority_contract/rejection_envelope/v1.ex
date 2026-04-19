defmodule Citadel.AuthorityContract.RejectionEnvelope.V1 do
  @moduledoc """
  Platform rejection envelope for Phase 4 fail-closed paths.
  """

  alias Citadel.ContractCore.AttrMap
  alias Citadel.ContractCore.CanonicalJson

  @contract_name "Platform.RejectionEnvelope.v1"
  @contract_version "1.0.0"
  @classes [:auth_error, :validation_error, :policy_error, :semantic_failure, :runtime_error]
  @retry_postures [:never, :after_input_change, :after_operator_action, :after_backoff]
  @operator_visibilities [:hidden, :summary, :full_operator]
  @statuses [:rejected, :quarantined, :suppressed]

  @fields [
    :contract_name,
    :contract_version,
    :rejection_id,
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
    :rejection_code,
    :rejection_class,
    :retry_posture,
    :operator_visibility,
    :http_status_or_rpc_status,
    :status,
    :safe_action_code,
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

  @spec rejection_classes() :: [atom()]
  def rejection_classes, do: @classes

  @spec retry_postures() :: [atom()]
  def retry_postures, do: @retry_postures

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = envelope), do: normalize(envelope)

  def new(attrs) do
    {:ok, build!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(%__MODULE__{} = envelope) do
    case normalize(envelope) do
      {:ok, normalized} -> normalized
      {:error, %ArgumentError{} = error} -> raise error
    end
  end

  def new!(attrs), do: build!(attrs)

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = envelope) do
    @fields
    |> Map.new(&{&1, Map.fetch!(envelope, &1)})
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

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
      rejection_id:
        attrs |> AttrMap.fetch!(:rejection_id, @contract_name) |> string!(:rejection_id),
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
      rejection_code:
        attrs |> AttrMap.fetch!(:rejection_code, @contract_name) |> string!(:rejection_code),
      rejection_class:
        attrs
        |> AttrMap.fetch!(:rejection_class, @contract_name)
        |> enum!(@classes, :rejection_class),
      retry_posture:
        attrs
        |> AttrMap.fetch!(:retry_posture, @contract_name)
        |> enum!(@retry_postures, :retry_posture),
      operator_visibility:
        attrs
        |> AttrMap.fetch!(:operator_visibility, @contract_name)
        |> enum!(@operator_visibilities, :operator_visibility),
      http_status_or_rpc_status:
        attrs
        |> AttrMap.fetch!(:http_status_or_rpc_status, @contract_name)
        |> string!(:http_status_or_rpc_status),
      status: attrs |> AttrMap.fetch!(:status, @contract_name) |> enum!(@statuses, :status),
      safe_action_code:
        attrs |> AttrMap.fetch!(:safe_action_code, @contract_name) |> string!(:safe_action_code),
      message: attrs |> AttrMap.fetch!(:message, @contract_name) |> string!(:message),
      details: attrs |> AttrMap.fetch!(:details, @contract_name) |> json_object!(:details),
      redaction: attrs |> AttrMap.fetch!(:redaction, @contract_name) |> json_object!(:redaction)
    }
  end

  defp normalize(%__MODULE__{} = envelope) do
    {:ok, envelope |> dump() |> build!()}
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

  defp json_object!(value, field) do
    normalized = CanonicalJson.normalize!(value)

    unless is_map(normalized) do
      raise ArgumentError, "#{@contract_name}.#{field} must normalize to a JSON object"
    end

    normalized
  end
end
