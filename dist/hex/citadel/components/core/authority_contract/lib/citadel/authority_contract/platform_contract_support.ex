defmodule Citadel.AuthorityContract.PlatformContractSupport do
  @moduledoc false

  alias Citadel.ContractCore.AttrMap
  alias Citadel.ContractCore.CanonicalJson

  @spec normalize_attrs!(map() | keyword(), String.t()) :: map()
  def normalize_attrs!(attrs, contract_name),
    do: AttrMap.normalize!(attrs, "#{contract_name} attrs")

  @spec required_string!(map(), atom(), String.t()) :: String.t()
  def required_string!(attrs, key, contract_name) do
    attrs
    |> AttrMap.fetch!(key, contract_name)
    |> string!(key, contract_name)
  end

  @spec optional_string!(map(), atom(), String.t()) :: String.t() | nil
  def optional_string!(attrs, key, contract_name) do
    case AttrMap.get(attrs, key) do
      nil -> nil
      value -> string!(value, key, contract_name)
    end
  end

  @spec actor_refs!(map(), String.t()) :: {String.t() | nil, String.t() | nil}
  def actor_refs!(attrs, contract_name) do
    principal_ref = optional_string!(attrs, :principal_ref, contract_name)
    system_actor_ref = optional_string!(attrs, :system_actor_ref, contract_name)

    if is_nil(principal_ref) and is_nil(system_actor_ref) do
      raise ArgumentError, "#{contract_name} requires principal_ref or system_actor_ref"
    end

    {principal_ref, system_actor_ref}
  end

  @spec literal!(term(), term(), atom(), String.t()) :: term()
  def literal!(value, expected, _key, _contract_name) when value == expected, do: value

  def literal!(value, expected, key, contract_name) do
    raise ArgumentError, "#{contract_name}.#{key} must be #{expected}, got: #{inspect(value)}"
  end

  @spec enum_atomish!(term(), [atom()], atom(), String.t()) :: atom()
  def enum_atomish!(value, allowed, key, contract_name) when is_binary(value) do
    allowed
    |> Enum.find(&(Atom.to_string(&1) == value))
    |> enum_atomish!(allowed, key, contract_name)
  end

  def enum_atomish!(value, allowed, key, contract_name) when is_atom(value) do
    if value in allowed do
      value
    else
      raise ArgumentError,
            "#{contract_name}.#{key} must be one of #{inspect(allowed)}, got: #{inspect(value)}"
    end
  end

  def enum_atomish!(value, allowed, key, contract_name) do
    raise ArgumentError,
          "#{contract_name}.#{key} must be one of #{inspect(allowed)}, got: #{inspect(value)}"
  end

  @spec non_neg_integer!(term(), atom(), String.t()) :: non_neg_integer()
  def non_neg_integer!(value, _key, _contract_name) when is_integer(value) and value >= 0,
    do: value

  def non_neg_integer!(value, key, contract_name) do
    raise ArgumentError,
          "#{contract_name}.#{key} must be a non-negative integer, got: #{inspect(value)}"
  end

  @spec required_non_neg_integer!(map(), atom(), String.t()) :: non_neg_integer()
  def required_non_neg_integer!(attrs, key, contract_name) do
    attrs
    |> AttrMap.fetch!(key, contract_name)
    |> non_neg_integer!(key, contract_name)
  end

  @spec optional_non_neg_integer!(map(), atom(), String.t()) :: non_neg_integer() | nil
  def optional_non_neg_integer!(attrs, key, contract_name) do
    case AttrMap.get(attrs, key) do
      nil -> nil
      value -> non_neg_integer!(value, key, contract_name)
    end
  end

  @spec required_datetime!(map(), atom(), String.t()) :: DateTime.t()
  def required_datetime!(attrs, key, contract_name) do
    attrs
    |> AttrMap.fetch!(key, contract_name)
    |> datetime!(key, contract_name)
  end

  @spec json_object!(map(), atom(), String.t()) :: %{required(String.t()) => term()}
  def json_object!(attrs, key, contract_name) do
    attrs
    |> AttrMap.fetch!(key, contract_name)
    |> normalize_json_object!(key, contract_name)
  end

  @spec non_empty_json_object!(map(), atom(), String.t()) :: %{required(String.t()) => term()}
  def non_empty_json_object!(attrs, key, contract_name) do
    object = json_object!(attrs, key, contract_name)

    if map_size(object) == 0 do
      raise ArgumentError, "#{contract_name}.#{key} must be a non-empty JSON object"
    end

    object
  end

  defp string!(value, key, contract_name) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "#{contract_name}.#{key} must be a non-empty string"
    end

    value
  end

  defp string!(value, key, contract_name) do
    raise ArgumentError,
          "#{contract_name}.#{key} must be a non-empty string, got: #{inspect(value)}"
  end

  defp datetime!(%DateTime{} = value, _key, _contract_name), do: value

  defp datetime!(value, key, contract_name) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> raise ArgumentError, "#{contract_name}.#{key} must be ISO-8601"
    end
  end

  defp datetime!(value, key, contract_name) do
    raise ArgumentError,
          "#{contract_name}.#{key} must be a DateTime or ISO-8601 string, got: #{inspect(value)}"
  end

  defp normalize_json_object!(value, key, contract_name) do
    normalized = CanonicalJson.normalize!(value)

    unless is_map(normalized) do
      raise ArgumentError, "#{contract_name}.#{key} must normalize to a JSON object"
    end

    normalized
  end
end
