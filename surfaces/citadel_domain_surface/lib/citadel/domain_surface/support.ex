defmodule Citadel.DomainSurface.Support do
  @moduledoc false

  alias Citadel.DomainSurface.Error

  @spec fetch_definition(term(), module(), atom()) ::
          {:ok, struct()} | {:error, Error.t()}
  def fetch_definition(source, definition_module, kind) do
    cond do
      match?(%^definition_module{}, source) ->
        {:ok, source}

      is_atom(source) ->
        fetch_module_definition(source, definition_module, kind)

      true ->
        {:error,
         Error.validation(
           :invalid_definition,
           invalid_definition_message(kind, source, "must be a definition struct or module"),
           definition_kind: kind
         )}
    end
  end

  @spec normalize_options(term()) :: {:ok, keyword()} | {:error, Error.t()}
  def normalize_options(opts) when is_list(opts) do
    if Keyword.keyword?(opts) do
      {:ok, opts}
    else
      {:error,
       Error.validation(
         :invalid_request,
         "options must be a keyword list",
         field: :options,
         actual: inspect(opts)
       )}
    end
  end

  def normalize_options(opts) do
    {:error,
     Error.validation(
       :invalid_request,
       "options must be a keyword list",
       field: :options,
       actual: inspect(opts)
     )}
  end

  @spec normalize_metadata(term()) :: {:ok, map()} | {:error, Error.t()}
  def normalize_metadata(nil), do: {:ok, %{}}

  def normalize_metadata(value) when is_list(value) do
    if Keyword.keyword?(value) do
      {:ok, Enum.into(value, %{})}
    else
      {:error,
       Error.validation(
         :invalid_metadata,
         "metadata must be a map, struct, or keyword list",
         actual: inspect(value)
       )}
    end
  end

  def normalize_metadata(%_{} = value), do: {:ok, Map.from_struct(value)}
  def normalize_metadata(value) when is_map(value), do: {:ok, value}

  def normalize_metadata(value) do
    {:error,
     Error.validation(
       :invalid_metadata,
       "metadata must be a map, struct, or keyword list",
       actual: inspect(value)
     )}
  end

  @spec normalize_context(term()) :: {:ok, map() | nil} | {:error, Error.t()}
  def normalize_context(nil), do: {:ok, nil}

  def normalize_context(value) when is_list(value) do
    if Keyword.keyword?(value) do
      {:ok, Enum.into(value, %{})}
    else
      {:error,
       Error.validation(
         :invalid_context,
         "context must be a map, struct, or keyword list",
         actual: inspect(value)
       )}
    end
  end

  def normalize_context(value) when is_map(value), do: {:ok, value}

  def normalize_context(value) do
    {:error,
     Error.validation(
       :invalid_context,
       "context must be a map, struct, or keyword list",
       actual: inspect(value)
     )}
  end

  @spec normalize_optional_string(term(), atom()) ::
          {:ok, String.t() | nil} | {:error, Error.t()}
  def normalize_optional_string(nil, _field), do: {:ok, nil}

  def normalize_optional_string(value, _field) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      {:error, Error.validation(:invalid_request, "string fields must not be blank")}
    else
      {:ok, trimmed}
    end
  end

  def normalize_optional_string(value, field) do
    {:error,
     Error.validation(
       :invalid_request,
       "#{field} must be a non-empty string when present",
       field: field,
       actual: inspect(value)
     )}
  end

  @spec resolve_trace_id(keyword(), map() | nil) ::
          {:ok, String.t() | nil} | {:error, Error.t()}
  def resolve_trace_id(opts, context) do
    trace_id =
      Keyword.get(opts, :trace_id) ||
        get_in_context(context, :trace_id) ||
        get_in_context(context, "trace_id")

    validate_trace_id(trace_id)
  end

  @spec get_in_context(map() | nil, atom() | String.t()) :: term()
  def get_in_context(nil, _key), do: nil
  def get_in_context(context, key) when is_map(context), do: Map.get(context, key)

  @spec stable_hash(term()) :: String.t()
  def stable_hash(value) do
    value
    |> canonicalize()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp validate_trace_id(nil), do: {:ok, nil}

  defp validate_trace_id(value) when is_binary(value) do
    if String.trim(value) == "" do
      {:error, Error.validation(:invalid_trace_id, "trace_id must be a non-empty string")}
    else
      {:ok, value}
    end
  end

  defp validate_trace_id(_value) do
    {:error, Error.validation(:invalid_trace_id, "trace_id must be a non-empty string")}
  end

  defp canonicalize(%_{} = value), do: value |> Map.from_struct() |> canonicalize()

  defp canonicalize(value) when is_map(value) do
    value
    |> Enum.map(fn {key, nested_value} -> {canonicalize(key), canonicalize(nested_value)} end)
    |> Enum.sort_by(fn {key, _value} -> :erlang.term_to_binary(key) end)
  end

  defp canonicalize(value) when is_list(value), do: Enum.map(value, &canonicalize/1)

  defp canonicalize(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&canonicalize/1)
    |> List.to_tuple()
  end

  defp canonicalize(value), do: value

  defp fetch_module_definition(module, definition_module, kind) do
    if Code.ensure_loaded?(module) and function_exported?(module, :definition, 0) do
      definition =
        module.definition()
        |> maybe_put_module(module)

      if match?(%^definition_module{}, definition) do
        {:ok, definition}
      else
        {:error,
         Error.validation(
           :invalid_definition,
           invalid_definition_message(
             kind,
             module,
             "definition/0 returned #{inspect(definition)}"
           ),
           definition_kind: kind,
           module: inspect(module)
         )}
      end
    else
      {:error,
       Error.validation(
         :invalid_definition,
         invalid_definition_message(kind, module, "module must export definition/0"),
         definition_kind: kind,
         module: inspect(module)
       )}
    end
  rescue
    error ->
      {:error,
       Error.validation(
         :invalid_definition,
         invalid_definition_message(kind, module, Exception.message(error)),
         definition_kind: kind,
         module: inspect(module)
       )}
  end

  defp invalid_definition_message(kind, source, detail) do
    "#{kind} definition #{inspect(source)} is invalid: #{detail}"
  end

  defp maybe_put_module(definition, module) when is_map(definition) do
    if Map.has_key?(definition, :module) do
      %{definition | module: module}
    else
      definition
    end
  end

  defp maybe_put_module(definition, _module), do: definition
end
