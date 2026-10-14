defmodule Styx.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [Styx.Registry, Styx.Notifiers.Listeners],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end
end
