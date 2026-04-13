defmodule Citadel.DomainSurface.Adapters.CitadelAdapter.Config do
  @moduledoc false

  alias Citadel.DomainSurface.{Error, Support}

  @type attrs ::
          keyword()
          | %{optional(atom() | String.t()) => term()}

  @type t :: %__MODULE__{
          id_port: module() | nil,
          request_submission: module() | nil,
          request_submission_opts: keyword(),
          query_surface: module() | nil,
          query_surface_opts: keyword(),
          maintenance_surface: module() | nil,
          maintenance_surface_opts: keyword(),
          context_defaults: map()
        }

  defstruct id_port: nil,
            request_submission: nil,
            request_submission_opts: [],
            query_surface: nil,
            query_surface_opts: [],
            maintenance_surface: nil,
            maintenance_surface_opts: [],
            context_defaults: %{}

  @spec new(t() | attrs()) :: {:ok, t()} | {:error, Error.t()}
  def new(%__MODULE__{} = config) do
    {:ok, validate!(config)}
  rescue
    error in ArgumentError ->
      {:error,
       Error.configuration(:not_configured, Exception.message(error), component: :citadel_adapter)}
  end

  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = Map.new(attrs)

    config = %__MODULE__{
      id_port: Map.get(attrs, :id_port, Map.get(attrs, "id_port")),
      request_submission:
        Map.get(attrs, :request_submission, Map.get(attrs, "request_submission")),
      request_submission_opts:
        normalize_keyword!(
          Map.get(attrs, :request_submission_opts, Map.get(attrs, "request_submission_opts", [])),
          :request_submission_opts
        ),
      query_surface: Map.get(attrs, :query_surface, Map.get(attrs, "query_surface")),
      query_surface_opts:
        normalize_keyword!(
          Map.get(attrs, :query_surface_opts, Map.get(attrs, "query_surface_opts", [])),
          :query_surface_opts
        ),
      maintenance_surface:
        Map.get(attrs, :maintenance_surface, Map.get(attrs, "maintenance_surface")),
      maintenance_surface_opts:
        normalize_keyword!(
          Map.get(
            attrs,
            :maintenance_surface_opts,
            Map.get(attrs, "maintenance_surface_opts", [])
          ),
          :maintenance_surface_opts
        ),
      context_defaults:
        normalize_context_defaults!(
          Map.get(attrs, :context_defaults, Map.get(attrs, "context_defaults", %{}))
        )
    }

    new(config)
  end

  defp validate!(%__MODULE__{} = config) do
    %__MODULE__{
      config
      | id_port: validate_module!(config.id_port, [new_id: 1], :id_port),
        request_submission:
          validate_module!(config.request_submission, [submit_envelope: 3], :request_submission),
        query_surface:
          validate_module!(
            config.query_surface,
            [fetch_runtime_observation: 2, fetch_boundary_session: 2],
            :query_surface
          ),
        maintenance_surface:
          validate_module!(
            config.maintenance_surface,
            [
              inspect_dead_letter: 3,
              clear_dead_letter: 4,
              retry_dead_letter: 4,
              replace_dead_letter: 5,
              recover_dead_letters: 4
            ],
            :maintenance_surface
          )
    }
  end

  defp validate_module!(nil, _callbacks, _field), do: nil

  defp validate_module!(module, callbacks, field) when is_atom(module) do
    Enum.each(callbacks, fn {name, arity} ->
      unless Code.ensure_loaded?(module) and function_exported?(module, name, arity) do
        raise ArgumentError,
              "citadel adapter #{field} must export #{name}/#{arity}, got: #{inspect(module)}"
      end
    end)

    module
  end

  defp validate_module!(value, _callbacks, field) do
    raise ArgumentError,
          "citadel adapter #{field} must be a module, got: #{inspect(value)}"
  end

  defp normalize_keyword!(value, _field) when value == [], do: []

  defp normalize_keyword!(value, field) when is_list(value) do
    if Keyword.keyword?(value) do
      value
    else
      raise ArgumentError, "citadel adapter #{field} must be a keyword list"
    end
  end

  defp normalize_keyword!(value, field) do
    raise ArgumentError,
          "citadel adapter #{field} must be a keyword list, got: #{inspect(value)}"
  end

  defp normalize_context_defaults!(value) do
    case Support.normalize_context(value) do
      {:ok, nil} -> %{}
      {:ok, context_defaults} -> context_defaults
      {:error, %Error{} = error} -> raise ArgumentError, error.message
    end
  end
end
