defmodule Citadel.Kernel.SystemClock do
  @moduledoc false

  @behaviour Citadel.Ports.Clock

  @impl true
  def utc_now, do: DateTime.utc_now()
end

defmodule Citadel.Kernel.NoopSignalSource do
  @moduledoc false

  @behaviour Citadel.Ports.SignalSource

  @deprecated "Use Citadel.Kernel.ObservationSignalSource instead"

  @impl true
  def normalize_signal(signal),
    do: Citadel.Kernel.ObservationSignalSource.normalize_signal(signal)
end
