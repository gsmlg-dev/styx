# Error Handling

This page guides you through handling and reporting errors in Styx.

Jobs can fail in expected or unexpected ways. To mark a job as failed, you can return `{:error,
reason}` from a worker's [`perform/1` callback](`c:Styx.Worker.perform/1`), as documented in the
`t:Styx.Worker.result/0` type. A job can also fail because of unexpected raised errors or exits.

In any case, when a job fails the details of the failure are recorded in the `errors` array on the
`Styx.Job` struct.

## Error Details

Styx stores execution errors as a list of maps (`t:Styx.Job.errors/0`). Each error contains the
following keys:

  * `:at` — The UTC timestamp when the error occurred at
  * `:attempt` — The attempt number when the error occurred
  * `:error` — A *formatted* error message and stacktrace

See the [Instrumentation docs](instrumentation.html) for an example of integrating with external
error reporting systems.

## Retries

When a job fails and the number of execution attempts is below the configured `max_attempts` limit
for that job, the job will automatically be retried in the future. If the number of failures
reaches `max_attempts`, the job gets **discarded**.

The retry delay has an *exponential backoff with jitter*. This means that the delay between
attempts grows exponentially (8s, 16s, and so on), and a randomized "jitter" is introduced for
each attempt, so that chances of jobs overlapping when being retried go down. So, a job could be
retried after 7.3s, then 17.1s, and so on.

See the `Styx.Worker` documentation on "Customizing Backoff" for alternative backoff strategies.

### Limiting Retries

By default, jobs are retried up to 20 times. The number of retries is controlled by the
`:max_attempts` value, which can be set at the **worker** or **job** level. For example, to
instruct a worker to discard jobs after three failures:

```elixir
use Styx.Worker, queue: :limited, max_attempts: 3
```

## Reporting Errors

Another great use of execution data and instrumentation is error reporting. Here is an example of
an event handler module that integrates with [Honeybadger][honeybadger] to report job failures:

```elixir
defmodule MyApp.ErrorReporter do
  def attach do
    :telemetry.attach(
      "styx-errors",
      [:styx, :job, :exception],
      &__MODULE__.handle_event/4,
      []
    )
  end

  def handle_event([:styx, :job, :exception], measure, meta, _) do
    Honeybadger.notify(meta.reason, stacktrace: meta.stacktrace)
  end
end

# Attach it with:
MyApp.ErrorReporter.attach()
```

You can use exception events to send error reports to Sentry, AppSignal, Honeybadger, Rollbar, or
any other application monitoring platform.

### Built-in Reporting

Some error-reporting and application-monitoring services support reporting Styx errors out of the
box:

  - Sentry — [Sentry package for Elixir][sentry-integration]
  - AppSignal — [AppSignal package for Elixir][appsignal-integration]

[honeybadger]: https://www.honeybadger.io
[sentry-integration]: https://hex.pm/packages/sentry
[appsignal-integration]: https://hex.pm/packages/appsignal
