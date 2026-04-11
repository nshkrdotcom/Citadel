defmodule Citadel.ContractCore.Value do
  @moduledoc false

  alias Citadel.ContractCore.AttrMap
  alias Citadel.ContractCore.CanonicalJson

  @spec normalize_attrs!(map() | keyword(), String.t(), [atom()]) :: map()
  def normalize_attrs!(attrs, context, allowed_fields) do
    attrs = AttrMap.normalize!(attrs, "#{context} attrs")
    reject_unknown_fields!(attrs, context, allowed_fields)
    attrs
  end

  @spec reject_unknown_fields!(map(), String.t(), [atom()]) :: :ok
  def reject_unknown_fields!(attrs, context, allowed_fields) when is_map(attrs) do
    allowed_keys = MapSet.new(Enum.map(allowed_fields, &Atom.to_string/1))

    unknown_keys =
      attrs
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(allowed_keys, &1))
      |> Enum.sort()

    if unknown_keys != [] do
      raise ArgumentError,
            "#{context} contains unsupported fields: #{inspect(unknown_keys)}"
    end

    :ok
  end

  @spec string!(term(), String.t(), keyword()) :: String.t()
  def string!(value, label, opts \\ [])

  def string!(value, label, opts) when is_binary(value) do
    trimmed? = Keyword.get(opts, :trim?, true)
    allow_empty? = Keyword.get(opts, :allow_empty?, false)
    normalized = if trimmed?, do: String.trim(value), else: value

    cond do
      normalized == "" and not allow_empty? ->
        raise ArgumentError, "#{label} must be a non-empty string"

      true ->
        normalized
    end
  end

  def string!(value, label, _opts) do
    raise ArgumentError, "#{label} must be a string, got: #{inspect(value)}"
  end

  @spec optional_string!(term(), String.t(), keyword()) :: String.t() | nil
  def optional_string!(value, label, opts \\ [])
  def optional_string!(nil, _label, _opts), do: nil
  def optional_string!(value, label, opts), do: string!(value, label, opts)

  @spec non_neg_integer!(term(), String.t()) :: non_neg_integer()
  def non_neg_integer!(value, _label) when is_integer(value) and value >= 0, do: value

  def non_neg_integer!(value, label) do
    raise ArgumentError, "#{label} must be a non-negative integer, got: #{inspect(value)}"
  end

  @spec positive_integer!(term(), String.t()) :: pos_integer()
  def positive_integer!(value, _label) when is_integer(value) and value > 0, do: value

  def positive_integer!(value, label) do
    raise ArgumentError, "#{label} must be a positive integer, got: #{inspect(value)}"
  end

  @spec boolean!(term(), String.t()) :: boolean()
  def boolean!(value, _label) when is_boolean(value), do: value

  def boolean!(value, label) do
    raise ArgumentError, "#{label} must be a boolean, got: #{inspect(value)}"
  end

  @spec confidence!(term(), String.t()) :: float()
  def confidence!(value, _label) when is_float(value) and value >= 0.0 and value <= 1.0, do: value
  def confidence!(value, _label) when is_integer(value) and value >= 0 and value <= 1, do: value / 1

  def confidence!(value, label) do
    raise ArgumentError, "#{label} must be between 0.0 and 1.0, got: #{inspect(value)}"
  end

  @spec enum!(term(), [atom()], String.t()) :: atom()
  def enum!(value, allowed, label) when is_list(allowed) do
    normalized =
      cond do
        is_atom(value) ->
          value

        is_binary(value) ->
          allowed
          |> Enum.find(&(Atom.to_string(&1) == value))
          |> case do
            nil ->
              raise ArgumentError,
                    "#{label} must be one of #{inspect(allowed)}, got: #{inspect(value)}"

            enum_value ->
              enum_value
          end

        true ->
          raise ArgumentError,
                "#{label} must be one of #{inspect(allowed)}, got: #{inspect(value)}"
      end

    if normalized in allowed do
      normalized
    else
      raise ArgumentError, "#{label} must be one of #{inspect(allowed)}, got: #{inspect(value)}"
    end
  end

  @spec list!(term(), String.t(), (term() -> term()), keyword()) :: list()
  def list!(value, label, item_fun, opts \\ []) when is_function(item_fun, 1) do
    allow_empty? = Keyword.get(opts, :allow_empty?, true)

    unless is_list(value) do
      raise ArgumentError, "#{label} must be a list, got: #{inspect(value)}"
    end

    if value == [] and not allow_empty? do
      raise ArgumentError, "#{label} must not be empty"
    end

    value
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> with_index_label(label, index, item_fun).(item) end)
  end

  @spec unique_strings!(term(), String.t(), keyword()) :: [String.t()]
  def unique_strings!(value, label, opts \\ []) do
    normalized = list!(value, label, &string!/1, opts)

    if Enum.uniq(normalized) == normalized do
      normalized
    else
      raise ArgumentError, "#{label} must not contain duplicates"
    end
  end

  @spec json_object!(term(), String.t()) :: map()
  def json_object!(value, label) do
    normalized = CanonicalJson.normalize!(value)

    if is_map(normalized) do
      normalized
    else
      raise ArgumentError, "#{label} must normalize to a JSON object"
    end
  end

  @spec json_value!(term(), String.t()) :: CanonicalJson.value()
  def json_value!(value, _label), do: CanonicalJson.normalize!(value)

  @spec map_of!(term(), String.t(), (String.t(), term() -> term())) :: map()
  def map_of!(value, label, entry_fun) when is_function(entry_fun, 2) do
    normalized = AttrMap.normalize!(value, label)

    Enum.reduce(normalized, %{}, fn {key, entry_value}, acc ->
      Map.put(acc, key, entry_fun.(key, entry_value))
    end)
  end

  @spec datetime!(term(), String.t()) :: DateTime.t()
  def datetime!(%DateTime{} = value, _label), do: value

  def datetime!(value, label) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, reason} -> raise ArgumentError, "#{label} must be ISO8601 datetime, got: #{inspect(reason)}"
    end
  end

  def datetime!(value, label) do
    raise ArgumentError, "#{label} must be a DateTime or ISO8601 string, got: #{inspect(value)}"
  end

  @spec optional_datetime!(term(), String.t()) :: DateTime.t() | nil
  def optional_datetime!(nil, _label), do: nil
  def optional_datetime!(value, label), do: datetime!(value, label)

  @spec module!(term(), module(), String.t()) :: struct()
  def module!(%module{} = value, module, _label), do: value

  def module!(value, module, label) when is_map(value) or is_list(value) do
    module.new!(value)
  rescue
    error in ArgumentError ->
      raise ArgumentError, "#{label} is invalid: #{Exception.message(error)}"
  end

  def module!(value, module, label) do
    raise ArgumentError, "#{label} must be #{inspect(module)}, got: #{inspect(value)}"
  end

  @spec optional_module!(term(), module(), String.t()) :: struct() | nil
  def optional_module!(nil, _module, _label), do: nil
  def optional_module!(value, module, label), do: module!(value, module, label)

  @spec put_optional(map(), atom(), term(), (term() -> term())) :: map()
  def put_optional(acc, _field, nil, _fun), do: acc

  def put_optional(acc, field, value, fun) when is_function(fun, 1) do
    Map.put(acc, field, fun.(value))
  end

  @spec required(map(), atom(), String.t(), (term() -> term())) :: term()
  def required(attrs, field, context, fun) when is_map(attrs) and is_function(fun, 1) do
    attrs
    |> AttrMap.fetch!(field, context)
    |> fun.()
  end

  @spec optional(map(), atom(), String.t(), (term() -> term()), term()) :: term()
  def optional(attrs, field, _context, fun, default \\ nil)
      when is_map(attrs) and is_function(fun, 1) do
    case AttrMap.get(attrs, field) do
      nil -> default
      value -> fun.(value)
    end
  end

  defp with_index_label(label, index, item_fun) do
    fn value ->
      try do
        item_fun.(value)
      rescue
        error in ArgumentError ->
          raise ArgumentError, "#{label}[#{index}] is invalid: #{Exception.message(error)}"
      end
    end
  end

  def string!(value), do: string!(value, "value")
end
