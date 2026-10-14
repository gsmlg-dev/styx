defmodule Styx.PeerTest do
  use Styx.Case, async: true

  alias Styx.{Peer, Registry}

  describe "configuration" do
    test "leadership is disabled when peer is false" do
      name = start_supervised_styx!(peer: false)

      refute Peer.leader?(name)
    end

    test "leadership is disabled along with plugins" do
      name = start_supervised_styx!(peer: nil, plugins: false)

      refute Peer.leader?(name)
    end
  end

  describe "compatibility" do
    @tag :dolphin
    test "maintaining leadership using the Dolphin engine" do
      name =
        start_supervised_styx!(
          engine: Styx.Engines.Dolphin,
          node: "web.1",
          peer: Styx.Peers.Database,
          repo: Styx.Test.DolphinRepo
        )

      assert Peer.leader?(name)
      assert "web.1" == Peer.get_leader(name)

      # Force a second election after the peer is leader
      assert %{leader?: true} =
               name
               |> Styx.Registry.whereis(Styx.Peer)
               |> GenServer.call(:election)
    end
  end

  for peer <- [Styx.Peers.Global, Styx.Peers.Database] do
    @peer peer

    describe "using #{peer}" do
      test "forwarding opts to peer instances" do
        assert_raise RuntimeError, ~r/key :unknown not found/, fn ->
          start_supervised_styx!(peer: {@peer, unknown: :option})
        end
      end

      test "a single node acquires leadership" do
        name = start_supervised_styx!(peer: @peer, node: "web.1")

        assert Peer.leader?(name)
        assert "web.1" == Peer.get_leader(name)
      end

      test "leadership transfers to another peer when the leader exits" do
        name = start_supervised_styx!(plugins: false)
        conf = %{Styx.config(name) | peer: {@peer, []}}

        peer_a = start_supervised!({Peer, conf: conf, name: Peer.A})

        Process.sleep(50)

        peer_b = start_supervised!({Peer, conf: conf, name: Peer.B})

        assert @peer.leader?(peer_a)

        stop_supervised(Peer.A)

        with_backoff([sleep: 10, total: 30], fn ->
          assert @peer.leader?(peer_b)
        end)
      end

      @tag :capture_log
      test "leadership checks return false after a timeout" do
        name = start_supervised_styx!(peer: @peer)

        assert Peer.leader?(name)

        name
        |> Registry.whereis(Peer)
        |> :sys.suspend()

        refute Peer.leader?(name, 10)
        refute Peer.get_leader(name, 10)
      end
    end
  end
end
