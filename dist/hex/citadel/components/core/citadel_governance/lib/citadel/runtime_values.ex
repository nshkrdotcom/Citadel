defmodule Citadel.RuntimeValues do
  @moduledoc """
  Manifest for the public runtime value contracts exported by Citadel
  governance.

  The concrete value modules live under `Citadel.RuntimeValues` source files
  but keep their existing public module names for API stability.
  """

  @modules [
    Citadel.StalenessRequirements,
    Citadel.BackoffPolicy,
    Citadel.LocalAction,
    Citadel.ActionOutboxEntry,
    Citadel.SessionOutbox,
    Citadel.SessionState,
    Citadel.PersistedSessionEnvelope,
    Citadel.PersistedSessionBlob,
    Citadel.SessionContinuityCommit
  ]

  @doc """
  Returns the stable public runtime value modules exported by this package.
  """
  def modules, do: @modules
end
