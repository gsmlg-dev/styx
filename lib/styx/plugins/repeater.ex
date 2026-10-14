defmodule Styx.Plugins.Repeater do
  @moduledoc false

  @behaviour Styx.Plugin

  use GenServer

  alias Styx.Plugin

  require Logger

  @impl Plugin
  def start_link(_opts) do
    Logger.warning(
      """
      Repeater is deprecated.

      Stager automatically forces polling when notifications aren't available. You can safely remove
      the Repeater from your plugins.
      """,
      domain: [:styx]
    )

    GenServer.start_link(__MODULE__, [])
  end

  @impl Plugin
  def validate(_opts), do: :ok

  @impl GenServer
  def init(_opts), do: :ignore
end
