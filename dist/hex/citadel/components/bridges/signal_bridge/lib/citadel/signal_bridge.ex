defmodule Citadel.SignalBridge do
  @moduledoc """
  Normalizes non-boundary runtime signals into `Citadel.RuntimeObservation`.
  """

  alias Citadel.RuntimeObservation

  defmodule Adapter do
    @moduledoc false

    @callback normalize_signal(term()) :: {:ok, map()} | {:error, atom()}
  end

  @manifest %{
    package: :citadel_signal_bridge,
    layer: :bridge,
    status: :wave_5_contract_frozen,
    owns: [:signal_ingress_normalization, :runtime_observation_translation, :lineage_preservation],
    internal_dependencies: [:citadel_core, :citadel_runtime, :citadel_observability_contract],
    external_dependencies: []
  }

  @boundary_lifecycle_kinds ["attach_grant", "boundary_session", "boundary_heartbeat", "lease_staleness"]

  @type t :: %__MODULE__{adapter: module()}
  defstruct adapter: nil

  @spec new!(keyword()) :: t()
  def new!(opts) do
    adapter = Keyword.fetch!(opts, :adapter)

    unless is_atom(adapter) and function_exported?(adapter, :normalize_signal, 1) do
      raise ArgumentError, "Citadel.SignalBridge.adapter must export normalize_signal/1"
    end

    %__MODULE__{adapter: adapter}
  end

  @spec normalize_signal(t(), term()) :: {:ok, RuntimeObservation.t(), t()} | {:error, atom(), t()}
  def normalize_signal(%__MODULE__{} = bridge, raw_signal) do
    if boundary_lifecycle_signal?(raw_signal) do
      {:error, :boundary_lifecycle_signal, bridge}
    else
      case bridge.adapter.normalize_signal(raw_signal) do
        {:ok, normalized_signal} ->
          {:ok, RuntimeObservation.new!(normalized_signal), bridge}

        {:error, reason} ->
          {:error, reason, bridge}
      end
    end
  end

  @spec normalized_signal_fields() :: [atom()]
  def normalized_signal_fields, do: [:signal_id, :signal_cursor, :event_kind, :payload, :subject_ref]

  @spec manifest() :: map()
  def manifest, do: @manifest

  defp boundary_lifecycle_signal?(raw_signal) when is_map(raw_signal) do
    kind =
      raw_signal["event_kind"] || raw_signal[:event_kind] || raw_signal["signal_type"] ||
        raw_signal[:signal_type] || raw_signal["family"] || raw_signal[:family]

    kind in @boundary_lifecycle_kinds
  end

  defp boundary_lifecycle_signal?(_raw_signal), do: false
end
