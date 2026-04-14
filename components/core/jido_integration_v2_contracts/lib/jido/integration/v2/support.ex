defmodule Jido.Integration.V2.Support do
  @moduledoc false

  @spec attrs!(map() | keyword(), module()) :: map()
  def attrs!(attrs, _module) when is_map(attrs), do: Map.new(attrs)

  def attrs!(attrs, module) when is_list(attrs) do
    if Keyword.keyword?(attrs) do
      Map.new(attrs)
    else
      raise ArgumentError,
            "#{inspect(module)} attrs must be a map, struct, or keyword list, got: #{inspect(attrs)}"
    end
  end

  def attrs!(attrs, module) do
    raise ArgumentError,
          "#{inspect(module)} attrs must be a map, struct, or keyword list, got: #{inspect(attrs)}"
  end

  @spec fetch(map(), atom()) :: term() | nil
  def fetch(attrs, key) when is_map(attrs) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
  end

  @spec fetch!(map(), atom(), String.t()) :: term()
  def fetch!(attrs, key, field_name) when is_map(attrs) do
    case fetch(attrs, key) do
      nil -> raise ArgumentError, "#{field_name} is required"
      value -> value
    end
  end

  @spec non_empty_string!(term(), String.t()) :: String.t()
  def non_empty_string!(value, field_name) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "#{field_name} must be a non-empty string, got: #{inspect(value)}"
    else
      value
    end
  end

  def non_empty_string!(value, field_name) do
    raise ArgumentError, "#{field_name} must be a non-empty string, got: #{inspect(value)}"
  end

  @spec map!(term(), String.t()) :: map()
  def map!(value, _field_name) when is_map(value), do: value

  def map!(value, field_name) do
    raise ArgumentError, "#{field_name} must be a map, got: #{inspect(value)}"
  end

  @spec list!(term(), String.t(), (term() -> term())) :: [term()]
  def list!(value, _field_name, fun) when is_list(value), do: Enum.map(value, fun)

  def list!(value, field_name, _fun) do
    raise ArgumentError, "#{field_name} must be a list, got: #{inspect(value)}"
  end

  @spec struct!(term(), module(), String.t()) :: struct()
  def struct!(%mod{} = value, mod, _field_name), do: value

  def struct!(value, mod, _field_name) when is_map(value) or is_list(value), do: mod.new!(value)

  def struct!(value, mod, field_name) do
    raise ArgumentError,
          "#{field_name} must be a #{inspect(mod)} struct or attrs, got: #{inspect(value)}"
  end

  @spec optional_struct!(term(), module(), String.t()) :: struct() | nil
  def optional_struct!(nil, _mod, _field_name), do: nil
  def optional_struct!(value, mod, field_name), do: struct!(value, mod, field_name)

  @spec enum!(term(), [atom()], String.t()) :: atom()
  def enum!(value, allowed, field_name) when is_atom(value) do
    if value in allowed do
      value
    else
      raise ArgumentError,
            "#{field_name} must be one of #{inspect(allowed)}, got: #{inspect(value)}"
    end
  end

  def enum!(value, allowed, field_name) when is_binary(value) do
    case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
      nil ->
        raise ArgumentError,
              "#{field_name} must be one of #{inspect(allowed)}, got: #{inspect(value)}"

      atom ->
        atom
    end
  end

  def enum!(value, allowed, field_name) do
    raise ArgumentError,
          "#{field_name} must be one of #{inspect(allowed)}, got: #{inspect(value)}"
  end

  @spec reference_uri(String.t(), atom(), String.t()) :: String.t()
  def reference_uri(namespace, kind, id) do
    namespace = non_empty_string!(namespace, "reference namespace")
    id = non_empty_string!(id, "reference id")
    "jido://v2/#{namespace}/#{kind}/#{URI.encode_www_form(id)}"
  end

  @spec wrap_new(module(), (-> struct())) :: {:ok, struct()} | {:error, Exception.t()}
  def wrap_new(_module, fun) when is_function(fun, 0) do
    {:ok, fun.()}
  rescue
    error in [ArgumentError] -> {:error, error}
  end

  @spec unwrap_new!({:ok, struct()} | {:error, Exception.t()}) :: struct()
  def unwrap_new!({:ok, value}), do: value
  def unwrap_new!({:error, %ArgumentError{} = error}), do: raise(error)
end
