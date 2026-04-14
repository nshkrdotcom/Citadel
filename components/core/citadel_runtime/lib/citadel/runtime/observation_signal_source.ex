defmodule Citadel.Runtime.ObservationSignalSource do
  @moduledoc """
  Default runtime signal source for already-normalized observations.

  Raw host signals require an explicit adapter above runtime ingress.
  """

  @behaviour Citadel.Ports.SignalSource

  alias Citadel.RuntimeObservation

  @impl true
  def normalize_signal(%RuntimeObservation{} = observation), do: {:ok, observation}

  def normalize_signal(_signal), do: {:error, :runtime_observation_required}
end
