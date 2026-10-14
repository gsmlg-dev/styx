defmodule Styx.TelemetryTest do
  use Styx.Case, async: true

  import ExUnit.CaptureLog

  alias Styx.{Config, PerformError, Telemetry, TelemetryHandler}

  def handle_query(_event, _measure, meta, pid) do
    send(pid, {:query, meta})
  end

  test "repo operations include the oban config" do
    :telemetry.attach(
      "repo-test",
      [:styx, :test, :repo, :query],
      &__MODULE__.handle_query/4,
      self()
    )

    name = start_supervised_oban!(queues: [alpha: 2])
    conf = Styx.config(name)

    Styx.Repo.all(conf, Styx.Job)

    assert_received {:query, %{options: [styx_conf: ^conf]}}
  after
    :telemetry.detach("repo-test")
  end

  test "telemetry event is emitted for supervisor initialization" do
    TelemetryHandler.attach_events()

    name = start_supervised_oban!(queues: [alpha: 2])
    pid = Styx.Registry.whereis(name)
    conf = Styx.config(name)

    assert_receive {:event, [:styx, :supervisor, :init], %{system_time: _},
                    %{conf: ^conf, pid: ^pid}}
  end

  test "telemetry events are emitted for executed jobs" do
    TelemetryHandler.attach_events(span_type: [:job])

    name = start_supervised_oban!(stager: [interval: 5], queues: [alpha: 2])

    %Job{id: ok_id} = insert!([ref: 1, action: "OK"], tags: ["baz"])
    %Job{id: error_id} = insert!([ref: 2, action: "ERROR"], tags: ["foo"])

    assert_receive {:event, :start, started_time, %{conf: %Config{name: ^name}} = start_meta}
    assert_receive {:event, :stop, stop_meas, %{conf: %Config{name: ^name}} = stop_meta}

    assert_receive {:event, :exception, error_meas,
                    %{conf: %Config{name: ^name}, kind: :error} = error_meta}

    assert %{duration: stop_duration, queue_time: queue_time} = stop_meas
    assert %{memory: stop_memory, reductions: stop_reductions} = stop_meas
    assert %{duration: error_duration, queue_time: _} = error_meas

    assert started_time > 0
    assert stop_duration > 0
    assert stop_memory > 0
    assert stop_reductions > 0
    assert queue_time > 0
    assert error_duration > 0

    assert %{conf: %Config{name: ^name}, job: %Job{}} = start_meta
    assert %{conf: %Config{name: ^name}, job: %Job{id: ^ok_id}, result: :ok} = stop_meta
    assert %{conf: %Config{name: ^name}, job: %Job{id: ^error_id}, result: _} = error_meta

    assert %{job: %Job{unsaved_error: unsaved}} = error_meta
    assert %{kind: :error, reason: %PerformError{}, stacktrace: []} = unsaved

    # Deprecated Meta

    assert %{
             id: ^ok_id,
             args: %{},
             queue: "alpha",
             worker: "Styx.Integration.Worker",
             prefix: "public",
             attempt: 1,
             max_attempts: 20,
             state: :success,
             tags: ["baz"]
           } = stop_meta

    assert %{
             id: ^error_id,
             args: %{},
             queue: "alpha",
             worker: "Styx.Integration.Worker",
             prefix: "public",
             attempt: 1,
             max_attempts: 20,
             kind: :error,
             error: %PerformError{},
             stacktrace: [],
             state: :failure,
             tags: ["foo"]
           } = error_meta
  end

  test "reporting jobs still executing after the shutdown period" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:styx, :queue, :shutdown]])

    name = start_supervised_oban!(queues: [alpha: 10], shutdown_grace_period: 5)

    insert!(name, [ref: 1, sleep: 500], queue: :alpha)
    insert!(name, [ref: 2, sleep: 500], queue: :alpha)

    assert_receive {:started, 1}
    assert_receive {:started, 2}

    stop_supervised(name)

    assert_receive {_event, ^ref, %{elapsed: 5}, %{orphaned: [_, _], queue: "alpha"}}
  end

  describe "attach_default_logger/1" do
    setup context do
      name = context.test

      on_exit(fn -> Telemetry.detach_default_logger(styx_name: name) end)

      context
      |> Map.get(:logger_opts, [])
      |> Keyword.put_new(:level, :warning)
      |> Keyword.put(:styx_name, name)
      |> Telemetry.attach_default_logger()

      {:ok, name: name}
    end

    test "logging job event details", %{name: name} do
      # Use the Postgres notifier to prevent a notifier switch event and test inline to force
      # immediate execution.
      start_supervised_oban!(
        name: name,
        notifier: Styx.Notifiers.Postgres,
        testing: :inline
      )

      logged =
        capture_log(fn ->
          Styx.insert_all(name, [
            Worker.new(%{ref: 1, action: "OK"}),
            Worker.new(%{ref: 2, action: "ERROR"})
          ])

          assert_receive {:ok, 1}
          assert_receive {:error, 2}
        end)

      # Start

      assert logged =~ ~s("source":"styx")
      assert logged =~ ~s("event":"job:start")

      # Stop

      assert logged =~ ~s("event":"job:stop")
      assert logged =~ ~s("args":{)
      assert logged =~ ~s("attempt":1)
      assert logged =~ ~s("id":)
      assert logged =~ ~s("max_attempts":20)
      assert logged =~ ~s("meta":{)
      assert logged =~ ~s("queue":"alpha")
      assert logged =~ ~s("state":"success")
      assert logged =~ ~s("tags":[])
      assert logged =~ ~s("worker":"Styx.Integration.Worker")
      assert logged =~ ~r|"duration":\d{1,}|
      assert logged =~ ~r|"queue_time":\d{1,}|

      # Exception
      assert logged =~ ~s("event":"job:exception")
      assert logged =~ ~s("state":"failure")
      assert logged =~ ~s|"error":"** (Styx.PerformError)|
    end

    test "logging notifier switch events", %{name: name} do
      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :notifier, :switch], %{}, %{
            conf: %{name: name},
            status: :isolated
          })
        end)

      assert logged =~ ~s("source":"styx")
      assert logged =~ ~s("event":"notifier:switch")
      assert logged =~ ~s("message":"notifier can't receive messages)
    end

    test "logging peer leadership events", %{name: name} do
      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :peer, :election, :stop], %{}, %{
            conf: %{name: name, node: "worker.1"},
            leader: true,
            was_leader: false
          })
        end)

      assert logged =~ ~s("event":"peer:election")
      assert logged =~ ~s("leader":true)
      assert logged =~ ~s("node":"worker.1")
      assert logged =~ ~s("was_leader":false)
      assert logged =~ ~s("message":"peer became leader")
    end

    test "logging cron plugin events", %{name: name} do
      Code.ensure_loaded(Styx.Cron)

      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :plugin, :stop], %{duration: 1000}, %{
            conf: %{name: name},
            plugin: Styx.Cron,
            jobs: [%{id: 1}, %{id: 2}]
          })
        end)

      assert logged =~ ~s("event":"plugin:stop")
      assert logged =~ ~s("plugin":"Styx.Cron")
      assert logged =~ ~s("jobs":[1,2])
      assert logged =~ ~r|"duration":\d{1,}|
    end

    test "logging lifeline plugin events", %{name: name} do
      Code.ensure_loaded(Styx.Lifeline)

      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :plugin, :stop], %{duration: 1000}, %{
            conf: %{name: name},
            plugin: Styx.Lifeline,
            discarded_jobs: [%{id: 1}, %{id: 2}],
            rescued_jobs: [%{id: 3}]
          })
        end)

      assert logged =~ ~s("event":"plugin:stop")
      assert logged =~ ~s("plugin":"Styx.Lifeline")
      assert logged =~ ~s("discarded_jobs":[1,2])
      assert logged =~ ~s("rescued_jobs":[3])
      assert logged =~ ~r|"duration":\d{1,}|
    end

    test "logging pruner plugin events", %{name: name} do
      Code.ensure_loaded(Styx.Pruner)

      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :plugin, :stop], %{duration: 1000}, %{
            conf: %{name: name},
            plugin: Styx.Pruner,
            pruned_count: 9
          })
        end)

      assert logged =~ ~s("event":"plugin:stop")
      assert logged =~ ~s("plugin":"Styx.Pruner")
      assert logged =~ ~s("pruned_count":9)
      assert logged =~ ~r|"duration":\d{1,}|
    end

    test "logging plugin stop events for a failed run", %{name: name} do
      Code.ensure_loaded(Styx.Cron)

      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :plugin, :stop], %{duration: 1000}, %{
            conf: %{name: name},
            plugin: Styx.Cron,
            jobs: [],
            error: %RuntimeError{message: "something went wrong"}
          })
        end)

      assert logged =~ ~s("event":"plugin:stop")
      assert logged =~ ~s("jobs":[])
      assert logged =~ ~s|"error":"** (RuntimeError)|
    end

    test "logging plugin exception events", %{name: name} do
      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :plugin, :exception], %{duration: 1000}, %{
            conf: %{name: name},
            plugin: Styx.Pruner,
            error: %RuntimeError{message: "something went wrong"}
          })
        end)

      assert logged =~ ~s("event":"plugin:exception")
      assert logged =~ ~s("plugin":"Styx.Pruner")
      assert logged =~ ~s|"error":"** (RuntimeError)|
    end

    test "logging stager switch events", %{name: name} do
      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :stager, :switch], %{}, %{
            conf: %{name: name},
            mode: :local
          })
        end)

      assert logged =~ ~s("event":"stager:switch")
      assert logged =~ ~s("message":"job staging switched to local mode)
    end

    test "logging orphaned job information at queue shutdown", %{name: name} do
      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :queue, :shutdown], %{elapsed: 500}, %{
            conf: %{name: name},
            queue: "alpha",
            orphaned: [100, 101, 102]
          })
        end)

      assert logged =~ ~s|"event":"queue:shutdown"|
      assert logged =~ ~s|"orphaned":[100,101,102]|
      assert logged =~ ~s|"queue":"alpha"|
      assert logged =~ ~s|"message":"jobs were orphaned because|
    end

    test "not logging anything on shutdown without orphans", %{name: name} do
      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :queue, :shutdown], %{}, %{
            conf: %{name: name},
            queue: "alpha",
            orphaned: []
          })
        end)

      refute logged =~ ~s|"event":"queue:shutdown"|
    end

    @tag logger_opts: [encode: false]
    test "disabling encoding on the default logger", %{name: name} do
      logged =
        capture_log(fn ->
          start_supervised_oban!(name: name, stager: [interval: 5], queues: [alpha: 3])

          insert!(name, [ref: 1, action: "OK"], queue: :alpha)

          assert_receive {:ok, 1}

          stop_supervised(name)
        end)

      assert logged =~ ~s(source: "styx")
      assert logged =~ ~s(event: "job:start")
    end

    @tag logger_opts: [encode: false, events: [:notifier, :stager]]
    test "restricting events to the provided categories", %{name: name} do
      logged =
        capture_log(fn ->
          :telemetry.execute([:styx, :notifier, :switch], %{}, %{
            conf: %{name: name},
            status: :isolated
          })

          :telemetry.execute([:styx, :queue, :shutdown], %{}, %{
            conf: %{name: name},
            queue: "alpha",
            orphaned: []
          })

          :telemetry.execute([:styx, :stager, :switch], %{}, %{
            conf: %{name: name},
            mode: :local
          })
        end)

      assert logged =~ ~s(event: "notifier:switch")
      assert logged =~ ~s(event: "stager:switch")
      refute logged =~ ~s(event: "queue:shutdown")
    end
  end
end
