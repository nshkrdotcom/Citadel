defmodule Citadel.DomainSurface.Adapters.CitadelAdapter.Accepted do
  @moduledoc """
  Typed representation of a successful Citadel command acceptance.
  """

  @type attrs :: keyword() | %{optional(atom() | String.t()) => term()}
  @type metadata :: %{optional(atom()) => term()}

  @type t :: %__MODULE__{
          request_id: String.t(),
          session_id: String.t() | nil,
          trace_id: String.t(),
          ingress_path: atom() | nil,
          lifecycle_event: atom() | nil,
          continuity_revision: non_neg_integer() | nil,
          metadata: metadata()
        }

  @enforce_keys [:request_id, :trace_id]
  defstruct [
    :request_id,
    :session_id,
    :trace_id,
    :ingress_path,
    :lifecycle_event,
    :continuity_revision,
    metadata: %{}
  ]

  @spec new!(attrs()) :: t()
  def new!(attrs) do
    attrs = Map.new(attrs)

    known_keys = [
      :request_id,
      :session_id,
      :trace_id,
      :ingress_path,
      :lifecycle_event,
      :continuity_revision,
      :metadata
    ]

    %__MODULE__{
      request_id: required_string!(attrs, :request_id),
      session_id: optional_string(attrs, :session_id),
      trace_id: required_string!(attrs, :trace_id),
      ingress_path: optional_atom(attrs, :ingress_path),
      lifecycle_event: optional_atom(attrs, :lifecycle_event),
      continuity_revision: optional_non_neg_integer(attrs, :continuity_revision),
      metadata:
        Map.get(attrs, :metadata, Map.get(attrs, "metadata", %{}))
        |> normalize_metadata!(
          Map.drop(attrs, known_keys ++ Enum.map(known_keys, &Atom.to_string/1))
        )
    }
  end

  defp required_string!(attrs, key) do
    value = Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))

    if is_binary(value) and String.trim(value) != "" do
      value
    else
      raise ArgumentError, "citadel acceptance #{inspect(key)} must be a non-empty string"
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

  defp optional_atom(attrs, key) do
    case Map.get(attrs, key, Map.get(attrs, Atom.to_string(key))) do
      nil ->
        nil

      value when is_atom(value) ->
        value

      value when is_binary(value) and value != "" ->
        binary_to_existing_atom!(value, key)

      value ->
        raise ArgumentError,
              "citadel acceptance #{inspect(key)} must be an atom or string, got: #{inspect(value)}"
    end
  end

  defp optional_non_neg_integer(attrs, key) do
    case Map.get(attrs, key, Map.get(attrs, Atom.to_string(key))) do
      nil ->
        nil

      value when is_integer(value) and value >= 0 ->
        value

      value ->
        raise ArgumentError,
              "citadel acceptance #{inspect(key)} must be a non-negative integer, got: #{inspect(value)}"
    end
  end

  defp normalize_metadata!(value, extras) when is_map(value) do
    Map.merge(extras, value)
  end

  defp normalize_metadata!(value, _extras) do
    raise ArgumentError, "citadel acceptance metadata must be a map, got: #{inspect(value)}"
  end

  defp binary_to_existing_atom!(value, key) do
    String.to_existing_atom(value)
  rescue
    _error in ArgumentError ->
      reraise ArgumentError,
              [
                "citadel acceptance #{inspect(key)} string value must refer to an existing atom"
              ],
              __STACKTRACE__
  end
end
