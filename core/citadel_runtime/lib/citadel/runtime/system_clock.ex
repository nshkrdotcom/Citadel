defmodule Citadel.Runtime.SystemClock do
  @moduledoc false

  @behaviour Citadel.Ports.Clock

  @impl true
  def utc_now, do: DateTime.utc_now()
end

defmodule Citadel.Runtime.NoopSignalSource do
  @moduledoc false

  @behaviour Citadel.Ports.SignalSource

  @deprecated "Use Citadel.Runtime.ObservationSignalSource instead"

  @impl true
  def normalize_signal(signal),
    do: Citadel.Runtime.ObservationSignalSource.normalize_signal(signal)
end
