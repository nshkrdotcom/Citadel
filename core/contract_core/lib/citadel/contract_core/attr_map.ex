defmodule Citadel.ContractCore.AttrMap do
  @moduledoc false

  @spec normalize!(map() | keyword(), String.t()) :: %{required(String.t()) => term()}
  def normalize!(attrs, context) when is_map(attrs) do
    attrs
    |> Map.to_list()
    |> build_attr_map!(context)
  end

  def normalize!(attrs, context) when is_list(attrs) do
    if Keyword.keyword?(attrs) do
      build_attr_map!(attrs, context)
    else
      raise ArgumentError,
            "#{context} attrs must be a map or keyword list, got: #{inspect(attrs)}"
    end
  end

  def normalize!(attrs, context) do
    raise ArgumentError, "#{context} attrs must be a map or keyword list, got: #{inspect(attrs)}"
  end

  @spec fetch!(map(), atom() | String.t(), String.t()) :: term()
  def fetch!(attrs, key, context) when is_map(attrs) do
    normalized_key = normalize_key!(key, context)

    case Map.fetch(attrs, normalized_key) do
      {:ok, value} ->
        value

      :error ->
        raise ArgumentError, "#{context} is missing required field #{inspect(normalized_key)}"
    end
  end

  @spec get(map(), atom() | String.t(), term()) :: term()
  def get(attrs, key, default \\ nil) when is_map(attrs) do
    Map.get(attrs, normalize_key!(key, "attr key"), default)
  end

  defp build_attr_map!(entries, context) do
    Enum.reduce(entries, %{}, fn {key, value}, acc ->
      normalized_key = normalize_key!(key, context)

      if Map.has_key?(acc, normalized_key) do
        raise ArgumentError,
              "#{context} contains duplicate field after normalization: #{inspect(normalized_key)}"
      end

      Map.put(acc, normalized_key, value)
    end)
  end

  defp normalize_key!(key, _context) when is_binary(key), do: key
  defp normalize_key!(key, _context) when is_atom(key), do: Atom.to_string(key)

  defp normalize_key!(key, context) do
    raise ArgumentError,
          "#{context} contains unsupported field key #{inspect(key)}; expected atom or string"
  end
end
