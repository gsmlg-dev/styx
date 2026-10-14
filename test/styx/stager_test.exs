defmodule Styx.StagerTest do
  use Styx.Case, async: true

  alias Styx.{Sonar, Stager}
  alias Styx.TelemetryHandler

  test "descheduling jobs to make them available for execution" do
    job_1 = insert!(%{}, state: "scheduled", scheduled_at: seconds_ago(10))
    job_2 = insert!(%{}, state: "scheduled", scheduled_at: seconds_from_now(10))
    job_3 = insert!(%{}, state: "retryable")

    start_supervised_styx!(stager: [interval: 5], testing: :disabled)

    with_backoff(fn ->
      assert %{state: "available"} = Repo.reload(job_1)
      assert %{state: "scheduled"} = Repo.reload(job_2)
      assert %{state: "available"} = Repo.reload(job_3)
    end)
  end

  test "emitting telemetry data for staged jobs" do
    name = start_supervised_styx!(stager: [interval: 5], testing: :disabled)

    TelemetryHandler.attach_events(styx_name: name)

    assert_receive {:event, :stop, %{duration: _}, %{plugin: Stager} = meta}

    assert %{staged_count: _, staged_jobs: []} = meta
  end

  test "switching to local mode without functional pubsub" do
    :telemetry_test.attach_event_handlers(self(), [[:styx, :stager, :switch]])

    [stager: [interval: 5], notifier: {Styx.Notifiers.Isolated, connected: false}]
    |> start_supervised_styx!()
    |> ping_sonar()

    assert_receive {[:styx, :stager, :switch], _, %{}, %{mode: :local}}
  end

  test "switching to local mode when solitary and not the leader" do
    :telemetry_test.attach_event_handlers(self(), [[:styx, :stager, :switch]])

    opts = [
      stager: [interval: 5],
      notifier: Styx.Notifiers.Isolated,
      peer: {Styx.Peers.Isolated, leader?: false}
    ]

    opts
    |> start_supervised_styx!()
    |> ping_sonar()

    assert_receive {[:styx, :stager, :switch], _, %{}, %{mode: :local}}
  end

  test "dispatching directly to registered producers in local mode" do
    name =
      start_supervised_styx!(
        stager: [interval: 5],
        notifier: Styx.Notifiers.Isolated,
        peer: {Styx.Peers.Isolated, leader?: false}
      )

    ping_sonar(name)

    with {:via, _, {_, prod_name}} <- Styx.Registry.via(name, {:producer, "staging_test"}) do
      Registry.register(Styx.Registry, prod_name, nil)
    end

    assert_receive {:notification, :insert, %{"queue" => "staging_test"}}
  end

  defp ping_sonar(name) do
    name
    |> Styx.Registry.whereis(Sonar)
    |> GenServer.call(:ping)
  end
end
