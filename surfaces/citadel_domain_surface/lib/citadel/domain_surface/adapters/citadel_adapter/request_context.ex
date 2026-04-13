defmodule Citadel.DomainSurface.Adapters.CitadelAdapter.RequestContext do
  @moduledoc """
  Typed request context passed from the Domain boundary into Citadel seams.
  """

  @type attrs :: keyword() | %{optional(atom() | String.t()) => term()}
  @type trace_origin :: :host | :domain_minted

  @type t :: %__MODULE__{
          request_id: String.t(),
          session_id: String.t() | nil,
          tenant_id: String.t() | nil,
          actor_id: String.t() | nil,
          trace_id: String.t(),
          trace_origin: trace_origin(),
          idempotency_key: String.t() | nil,
          host_request_id: String.t() | nil,
          environment: String.t() | nil,
          policy_epoch: non_neg_integer(),
          metadata_keys: [String.t()]
        }

  @enforce_keys [:request_id, :trace_id, :trace_origin]
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

  @spec new!(attrs()) :: t()
  def new!(attrs) do
    attrs = Map.new(attrs)

    %__MODULE__{
      request_id: required_string!(attrs, :request_id),
      session_id: optional_string(attrs, :session_id),
      tenant_id: optional_string(attrs, :tenant_id),
      actor_id: optional_string(attrs, :actor_id),
      trace_id: required_string!(attrs, :trace_id),
      trace_origin: required_trace_origin!(attrs),
      idempotency_key: optional_string(attrs, :idempotency_key),
      host_request_id: optional_string(attrs, :host_request_id),
      environment: optional_string(attrs, :environment),
      policy_epoch: Map.get(attrs, :policy_epoch, Map.get(attrs, "policy_epoch", 0)),
      metadata_keys:
        normalize_metadata_keys(
          Map.get(attrs, :metadata_keys, Map.get(attrs, "metadata_keys", []))
        )
    }
  end

  defp required_string!(attrs, key) do
    value = Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))

    if is_binary(value) and String.trim(value) != "" do
      value
    else
      raise ArgumentError, "citadel request context #{inspect(key)} must be a non-empty string"
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

  defp required_trace_origin!(attrs) do
    case Map.get(attrs, :trace_origin, Map.get(attrs, "trace_origin")) do
      value when value in [:host, :domain_minted] ->
        value

      value ->
        raise ArgumentError,
              "citadel request context trace_origin must be :host or :domain_minted, got: #{inspect(value)}"
    end
  end

  defp normalize_metadata_keys(value) when is_list(value) do
    value
    |> Enum.map(fn
      key when is_atom(key) ->
        Atom.to_string(key)

      key when is_binary(key) ->
        key

      key ->
        raise ArgumentError,
              "citadel request context metadata_keys entries must be atoms or strings, got: #{inspect(key)}"
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp normalize_metadata_keys(value) do
    raise ArgumentError,
          "citadel request context metadata_keys must be a list, got: #{inspect(value)}"
  end
end
