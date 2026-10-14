defmodule Styx.TelemetryHandler do
  @moduledoc """
  This utility module is used during job tests to capture telemetry events
  and send them back to the test processes that registered the handler.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @span_tail [:start, :stop, :exception]
  @span_type [
    :job,
    :plugin,
    [:engine, :insert_job],
    [:engine, :insert_all_jobs],
    [:engine, :fetch_jobs],
    [:peer, :election]
  ]

  def attach_events(opts \\ []) do
    span_tail = Keyword.get(opts, :span_tail, @span_tail)
    span_type = Keyword.get(opts, :span_type, @span_type)
    styx_name = Keyword.get(opts, :styx_name, :all)

    name = name()

    events =
      for type <- span_type, tail <- span_tail do
        List.flatten([:styx, type, tail])
      end

    events = [[:styx, :supervisor, :init] | events]

    on_exit(fn -> :telemetry.detach(name) end)

    :telemetry.attach_many(name, events, &handle/4, {self(), styx_name})
  end

  def handle(event, measure, meta, {pid, styx_name}) do
    if styx_name == :all or match?(%{conf: %{name: ^styx_name}}, meta) do
      dispatch(event, measure, meta, pid)
    end
  end

  defp dispatch([:styx, :job, :start], %{system_time: start_time}, meta, pid) do
    send(pid, {:event, :start, start_time, meta})
  end

  defp dispatch([:styx, :job, event], measure, meta, pid) do
    send(pid, {:event, event, measure, meta})
  end

  defp dispatch([:styx, :engine | event], measure, meta, pid) do
    send(pid, {:event, event, measure, meta})
  end

  defp dispatch([:styx, :plugin, event], measure, meta, pid) do
    send(pid, {:event, event, measure, meta})
  end

  defp dispatch([:styx, :peer | event], measure, meta, pid) do
    send(pid, {:event, event, measure, meta})
  end

  defp dispatch(event, measure, meta, pid) do
    send(pid, {:event, event, measure, meta})
  end

  defp name, do: "handler-#{System.unique_integer([:positive])}"
end
