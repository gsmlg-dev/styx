defmodule Styx.Peers.Isolated do
  @moduledoc false

  @behaviour Styx.Peer

  @impl Styx.Peer
  def start_link(opts) do
    state =
      opts
      |> Keyword.put_new(:leader?, true)
      |> Map.new()

    Agent.start_link(fn -> state end, name: opts[:name])
  end

  @impl Styx.Peer
  def leader?(pid, timeout \\ 5_000) do
    Agent.get(pid, & &1.leader?, timeout)
  end

  @impl Styx.Peer
  def get_leader(pid, timeout \\ 5_000) do
    Agent.get(pid, fn state -> if state.leader?, do: state.conf.node, else: nil end, timeout)
  end
end
