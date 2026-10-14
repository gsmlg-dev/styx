defmodule Styx.Peers.IsolatedTest do
  use Styx.Case, async: true

  describe "get_leader/2" do
    test "returning the current node only when leader" do
      name = start_supervised_styx!(peer: {Styx.Peers.Isolated, leader?: false})

      refute Styx.Peer.leader?(name)
      refute Styx.Peer.get_leader(name)

      name = start_supervised_styx!(peer: {Styx.Peers.Isolated, leader?: true})

      assert Styx.Peer.leader?(name)
      assert Styx.Peer.get_leader(name)
    end
  end
end
