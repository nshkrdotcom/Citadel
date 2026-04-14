defmodule Citadel.HostIngress.RequestContext do
  @moduledoc """
  Typed request context for the public structured host-ingress seam.
  """

  @type attrs :: keyword() | %{optional(atom() | String.t()) => term()}

  @type t :: %__MODULE__{
          request_id: String.t(),
          session_id: String.t(),
          tenant_id: String.t(),
          actor_id: String.t(),
          trace_id: String.t(),
          trace_origin: String.t() | nil,
          idempotency_key: String.t() | nil,
          host_request_id: String.t() | nil,
          environment: String.t() | nil,
          policy_epoch: non_neg_integer(),
          metadata_keys: [String.t()]
        }

  @enforce_keys [:request_id, :session_id, :tenant_id, :actor_id, :trace_id]
  defstruct [
    :request_id,
    :session_id,
    :tenant_id,
    :actor_id,
    :trace_id,
    :trace_origin,
    :idempotency_key,
    :host_request_id,
    :environment,
    policy_epoch: 0,
    metadata_keys: []
  ]

  @spec new!(t()) :: t()
  def new!(%__MODULE__{} = context), do: context

  @spec new!(attrs()) :: t()
  def new!(attrs) do
    attrs = Map.new(attrs)

    %__MODULE__{
      request_id: required_string!(attrs, :request_id),
      session_id: required_string!(attrs, :session_id),
      tenant_id: required_string!(attrs, :tenant_id),
      actor_id: required_string!(attrs, :actor_id),
      trace_id: required_string!(attrs, :trace_id),
      trace_origin: optional_trace_origin(attrs),
      idempotency_key: optional_string(attrs, :idempotency_key),
      host_request_id: optional_string(attrs, :host_request_id),
      environment: optional_string(attrs, :environment),
      policy_epoch: optional_non_neg_integer(attrs, :policy_epoch, 0),
      metadata_keys:
        normalize_metadata_keys(
          Map.get(attrs, :metadata_keys, Map.get(attrs, "metadata_keys", []))
        )
    }
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = context) do
    %{
      request_id: context.request_id,
      session_id: context.session_id,
      tenant_id: context.tenant_id,
      actor_id: context.actor_id,
      trace_id: context.trace_id,
      trace_origin: context.trace_origin,
      idempotency_key: context.idempotency_key,
      host_request_id: context.host_request_id,
      environment: context.environment,
      policy_epoch: context.policy_epoch,
      metadata_keys: context.metadata_keys
    }
  end

  defp required_string!(attrs, key) do
    value = Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))

    if is_binary(value) and String.trim(value) != "" do
      value
    else
      raise ArgumentError,
            "host ingress request context #{inspect(key)} must be a non-empty string"
    end
  end

  defp optional_string(attrs, key) do
    value = Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))

    if is_binary(value) and String.trim(value) != "" do
      value
    else
      nil
    end
  end

  defp optional_trace_origin(attrs) do
    case Map.get(attrs, :trace_origin, Map.get(attrs, "trace_origin")) do
      nil ->
        nil

      value when is_atom(value) ->
        Atom.to_string(value)

      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed != "" do
          trimmed
        else
          raise ArgumentError,
                "host ingress request context trace_origin must be an atom or non-empty string, got: #{inspect(value)}"
        end

      value ->
        raise ArgumentError,
              "host ingress request context trace_origin must be an atom or non-empty string, got: #{inspect(value)}"
    end
  end

  defp optional_non_neg_integer(attrs, key, default) do
    case Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default)) do
      value when is_integer(value) and value >= 0 ->
        value

      value ->
        raise ArgumentError,
              "host ingress request context #{inspect(key)} must be a non-negative integer, got: #{inspect(value)}"
    end
  end

  defp normalize_metadata_keys(value) when is_list(value) do
    value
    |> Enum.map(fn
      item when is_atom(item) ->
        Atom.to_string(item)

      item when is_binary(item) and item != "" ->
        item

      item ->
        raise ArgumentError,
              "host ingress metadata_keys entries must be atoms or non-empty strings, got: #{inspect(item)}"
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp normalize_metadata_keys(value) do
    raise ArgumentError,
          "host ingress metadata_keys must be a list, got: #{inspect(value)}"
  end
end
