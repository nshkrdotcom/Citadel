defmodule Citadel.DomainSurface.Orchestration do
  @moduledoc """
  Explicit orchestration posture for Domain routes.

  Domain is stateless-by-default. When a route declares
  `:stateful_long_running`, it must also name durable backing. Otherwise the
  route is rejected explicitly instead of hiding saga state in memory.
  """

  alias Citadel.DomainSurface.Error

  @type mode :: :stateless_sync | :stateful_long_running
  @type durable_backing :: nil | :host_store | :external_adapter | module() | {atom(), module()}

  @enforce_keys [:mode]
  defstruct [:mode, :durable_backing, :description]

  @type t :: %__MODULE__{
          mode: mode(),
          durable_backing: durable_backing(),
          description: String.t() | nil
        }

  @spec define!(atom() | map() | keyword()) :: t()
  def define!(mode) when is_atom(mode),
    do: %__MODULE__{mode: normalize_mode!(mode), durable_backing: nil}

  def define!(attrs) do
    attrs = Map.new(attrs)

    %__MODULE__{
      mode: normalize_mode!(Map.get(attrs, :mode, :stateless_sync)),
      durable_backing: Map.get(attrs, :durable_backing),
      description: normalize_description(Map.get(attrs, :description))
    }
  end

  @spec stateless_sync() :: t()
  def stateless_sync, do: %__MODULE__{mode: :stateless_sync, durable_backing: nil}

  @spec supported?(t()) :: boolean()
  def supported?(%__MODULE__{mode: :stateless_sync}), do: true

  def supported?(%__MODULE__{mode: :stateful_long_running, durable_backing: durable_backing}),
    do: not is_nil(durable_backing)

  @spec validate(t(), keyword()) :: :ok | {:error, Error.t()}
  def validate(%__MODULE__{} = orchestration, opts \\ []) do
    if supported?(orchestration) do
      :ok
    else
      {:error, Error.unsupported_stateful_orchestration(orchestration, opts)}
    end
  end

  defp normalize_mode!(:stateless_sync), do: :stateless_sync
  defp normalize_mode!(:stateful_long_running), do: :stateful_long_running

  defp normalize_mode!(value) do
    raise ArgumentError,
          "orchestration mode must be :stateless_sync or :stateful_long_running, got: #{inspect(value)}"
  end

  defp normalize_description(nil), do: nil
  defp normalize_description(value) when is_binary(value), do: String.trim(value)

  defp normalize_description(value) do
    raise ArgumentError, "orchestration description must be a string, got: #{inspect(value)}"
  end
end
