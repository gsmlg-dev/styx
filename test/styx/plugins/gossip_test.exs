defmodule Styx.Plugins.GossipTest do
  use Styx.Case, async: true

  import ExUnit.CaptureLog

  test "ignoring plugin startup" do
    assert capture_log(fn ->
             start_supervised_oban!(plugins: [Styx.Plugins.Gossip])
           end) =~ "Gossip is deprecated"
  end
end
