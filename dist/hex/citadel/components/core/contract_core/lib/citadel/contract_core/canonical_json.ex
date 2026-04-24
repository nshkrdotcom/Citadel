defmodule Citadel.ContractCore.CanonicalJson do
  @moduledoc """
  Canonical JSON normalization and RFC 8785 / JCS encoding helpers.

  Shared packet hashing flows through this module so Citadel code can normalize
  packet values explicitly before `Jcs.encode/1` without relying on
  implementation-defined map ordering or struct enumeration.
  """

  @typedoc "JSON-safe scalar value after normalization"
  @type scalar :: nil | boolean() | integer() | float() | String.t()

  @typedoc "Normalized JSON value with string-keyed objects only"
  @type value :: scalar() | [value()] | %{required(String.t()) => value()}

  @spec encoder_module() :: module()
  def encoder_module, do: Jcs

  @spec normalize(term()) :: {:ok, value()} | {:error, Exception.t()}
  def normalize(input) do
    {:ok, normalize!(input)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec normalize!(term()) :: value()
  def normalize!(input), do: normalize_value!(input, [])

  @spec encode(term()) :: {:ok, String.t()} | {:error, Exception.t()}
  def encode(input) do
    {:ok, encode!(input)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec encode!(term()) :: String.t()
  def encode!(input) do
    input
    |> normalize!()
    |> Jcs.encode()
  end

  @spec encode_inline!(term(), keyword()) :: String.t()
  def encode_inline!(input, opts) when is_list(opts) do
    max_bytes =
      opts
      |> Keyword.fetch!(:max_bytes)
      |> validate_max_bytes!()

    label =
      opts
      |> Keyword.get(:label, "Canonical JSON input")
      |> validate_label!()

    reject_oversized_inline!(input, max_bytes, label)
    encode!(input)
  end

  defp reject_oversized_inline!(input, max_bytes, label) do
    estimated_bytes = :erlang.external_size(input)

    if estimated_bytes > max_bytes do
      raise ArgumentError,
            "#{label} exceeds inline canonicalization byte limit of #{max_bytes} bytes " <>
              "(estimated #{estimated_bytes} bytes) before canonical JSON encoding"
    end

    :ok
  end

  defp validate_max_bytes!(value) when is_integer(value) and value > 0, do: value

  defp validate_max_bytes!(value) do
    raise ArgumentError, "max_bytes must be a positive integer, got: #{inspect(value)}"
  end

  defp validate_label!(value) when is_binary(value) and byte_size(value) > 0, do: value

  defp validate_label!(value) do
    raise ArgumentError, "label must be a non-empty string, got: #{inspect(value)}"
  end

  defp normalize_value!(value, _path)
       when is_binary(value) or is_integer(value) or is_boolean(value) or is_nil(value),
       do: value

  defp normalize_value!([], _path), do: []

  defp normalize_value!(value, path) when is_float(value) do
    if finite_float?(value) do
      value
    else
      raise ArgumentError, "#{format_path(path)} must be a finite float, got: #{inspect(value)}"
    end
  end

  defp normalize_value!(value, _path) when is_atom(value), do: Atom.to_string(value)

  defp normalize_value!(value, path) when is_list(value) do
    if Keyword.keyword?(value) do
      normalize_object_entries!(value, path, :keyword_list)
    else
      value
      |> Enum.with_index()
      |> Enum.map(fn {entry, index} -> normalize_value!(entry, [index | path]) end)
    end
  end

  defp normalize_value!(%DateTime{} = value, _path) do
    value
    |> DateTime.to_unix(:microsecond)
    |> DateTime.from_unix!(:microsecond)
    |> DateTime.to_iso8601()
  end

  defp normalize_value!(%NaiveDateTime{} = value, _path), do: NaiveDateTime.to_iso8601(value)
  defp normalize_value!(%Date{} = value, _path), do: Date.to_iso8601(value)
  defp normalize_value!(%Time{} = value, _path), do: Time.to_iso8601(value)

  defp normalize_value!(%_{} = value, path) do
    raise ArgumentError,
          "#{format_path(path)} contains unsupported struct #{inspect(value.__struct__)}; " <>
            "project packet-owned structs into plain maps before canonicalization"
  end

  defp normalize_value!(value, path) when is_map(value) do
    normalize_object_entries!(Map.to_list(value), path, :map)
  end

  defp normalize_value!(value, path) do
    raise ArgumentError,
          "#{format_path(path)} contains unsupported non-JSON value: #{inspect(value)}"
  end

  defp normalize_object_entries!(entries, path, source_kind) do
    Enum.reduce(entries, %{}, fn {key, nested_value}, acc ->
      normalized_key = normalize_object_key!(key, path)

      if Map.has_key?(acc, normalized_key) do
        raise ArgumentError,
              "#{format_path(path)} contains duplicate #{source_kind} key after normalization: " <>
                inspect(normalized_key)
      end

      Map.put(acc, normalized_key, normalize_value!(nested_value, [normalized_key | path]))
    end)
  end

  defp normalize_object_key!(key, _path) when is_binary(key), do: key
  defp normalize_object_key!(key, _path) when is_atom(key), do: Atom.to_string(key)

  defp normalize_object_key!(key, path) do
    raise ArgumentError,
          "#{format_path(path)} contains unsupported object key #{inspect(key)}; " <>
            "canonical JSON object keys must be strings or atoms"
  end

  defp finite_float?(value) when is_float(value) do
    value
    |> :erlang.float_to_binary([:short])
    |> then(&(&1 not in ["nan", "inf", "-inf"]))
  end

  defp format_path([]), do: "value"

  defp format_path(path) do
    path
    |> Enum.reverse()
    |> Enum.reduce("value", fn
      segment, acc when is_integer(segment) -> "#{acc}[#{segment}]"
      segment, acc -> "#{acc}.#{segment}"
    end)
  end
end
