defmodule Citadel.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    :ok

    children = [
      %{
        id: Citadel.Kernel.Application,
        start: {Citadel.Kernel.Application, :start, [:normal, []]},
        type: :supervisor
      }
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: __MODULE__.Supervisor
    )
  end
end
