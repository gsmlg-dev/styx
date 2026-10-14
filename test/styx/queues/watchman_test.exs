defmodule Styx.Queues.WatchmanTest do
  use Styx.Case, async: true

  alias Styx.Queues.Watchman

  describe "terminate/2" do
    test "safely shutting down with missing processes" do
      opts = [
        name: WatchmanTest,
        shutdown: 1_000,
        producer: Watchman.Producer
      ]

      start_supervised!({Watchman, opts})

      assert :ok = stop_supervised(Watchman)
    end
  end
end
