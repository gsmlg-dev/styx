# Instrumentation and Logging

Styx provides integration with [Telemetry][telemetry], a dispatching library for metrics and
instrumentation. It is easy to report Styx metrics to any backend by attaching to Telemetry events
prefixed with `:styx`.

## Default Logger

The `Styx.Telemetry` module provides a robust structured logger that handles all of Styx's
telemetry events. As in the example above, attach it within your application module:

```elixir
:ok = Styx.Telemetry.attach_default_logger()
```

For more details on the default structured logger and information on event metadata see docs for
the `Styx.Telemetry` module.

## Custom Handlers

Here is an example of an unstructured log handler:

```elixir
defmodule MyApp.ObanLogger do
  require Logger

  def handle_event([:styx, :job, :start], measure, meta, _) do
    Logger.warning("[Styx] :started #{meta.worker} at #{measure.system_time}")
  end

  def handle_event([:styx, :job, event], measure, meta, _) do
    Logger.warning("[Styx] #{event} #{meta.worker} ran in #{measure.duration}")
  end
end
```

Attach the handler to success and failure events in your application's `c:Application.start/2`
callback (usually in `lib/my_app/application.ex`):

```elixir
def start(_type, _args) do
  events = [
    [:styx, :job, :start],
    [:styx, :job, :stop],
    [:styx, :job, :exception]
  ]

  :telemetry.attach_many("oban-logger", events, &MyApp.ObanLogger.handle_event/4, [])

  Supervisor.start_link(...)
end
```

[telemetry]: https://github.com/beam-telemetry/telemetry
