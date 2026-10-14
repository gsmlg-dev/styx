defmodule Styx.Plugins.RepeaterTest do
  use Styx.Case, async: true

  import ExUnit.CaptureLog

  test "ignoring plugin startup" do
    assert capture_log(fn ->
             start_supervised_oban!(plugins: [Styx.Plugins.Repeater])
           end) =~ "Repeater is deprecated"
  end
end
