defmodule Styx.Plugins.Gossip do
  @moduledoc false

  @behaviour Styx.Plugin

  use GenServer

  alias Styx.Plugin

  require Logger

  @impl Plugin
  def start_link(_opts) do
    Logger.warning("""
    Gossip is deprecated.

    Gossip is no longer needed for queue monitoring in Styx Web. You can safely remove Gossip from
    your plugins.
    """)

    GenServer.start_link(__MODULE__, [])
  end

  @impl Plugin
  def validate(_opts), do: :ok

  @impl GenServer
  def init(_opts), do: :ignore
end
