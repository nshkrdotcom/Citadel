defmodule Citadel.Runtime.SystemClock do
  @moduledoc false

  @behaviour Citadel.Ports.Clock

  @impl true
  def utc_now, do: DateTime.utc_now()
end

defmodule Citadel.Runtime.NoopSignalSource do
  @moduledoc false

  @behaviour Citadel.Ports.SignalSource

  alias Citadel.RuntimeObservation

  @impl true
  def normalize_signal(%RuntimeObservation{} = observation), do: {:ok, observation}

  def normalize_signal(_signal), do: {:error, :unsupported_signal}
end
