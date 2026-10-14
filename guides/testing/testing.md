# Introduction to Testing

Automated testing is an essential component of building reliable, long-lived
applications. Styx orchestrates your application's background tasks, so naturally,
testing Styx is highly recommended.

## Setup Application Config

Ensure your app is configured for testing before you begin running tests.

There are two testing modes available:

* `:inline`—jobs execute immediately within the calling process and without
  touching the database. This mode is simple and may not be suitable for apps
  with complex jobs.
* `:manual`—jobs are inserted into the database where they can be verified and
  executed when desired. This mode is more advanced and trades simplicity for
  flexibility.

If you're just starting out, `:inline` mode is recommended:

```elixir
config :my_app, Styx, testing: :inline
```

For more complex applications, or if you'd like complete control over when jobs
run, then use `:manual` mode instead:

```elixir
config :my_app, Styx, testing: :manual
```

Both testing modes prevent Styx from running any database queries in the
background. This simultaneously prevents Sandbox errors from plugin queries and
prevents queues from executing jobs unexpectedly.

### Changing Testing Modes

Once the application starts in a particular testing mode it can't be changed.
That's inconvenient if you're running in `:inline` mode and don't want a
particular job to execute inline! `Styx.Testing` provides a helper to
temporarily change testing modes within the context of a function.

For example, to switch to `:manual` mode when Styx is configured for `:inline`
testing:

```elixir
Styx.Testing.with_testing_mode(:manual, fn ->
  Styx.insert(MyWorker.new(%{id: 123}))

  assert_enqueued worker: MyWorker, args: %{id: 123}
end)
```

Or vice-versa, switch to `:inline` mode when the application is configured for
`:manual` mode:

```elixir
Styx.Testing.with_testing_mode(:inline, fn ->
  {:ok, %Job{state: "completed"}} = Styx.insert(MyWorker.new(%{id: 123}))
end)
```

## Setup Testing Helpers

Styx provides helpers to facilitate manual testing. These helpers handle the
boilerplate of making assertions on which jobs are enqueued.

The most convenient way to use the helpers is to `use` the module within your
test case:

```elixir
defmodule MyApp.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Styx.Testing, repo: MyApp.Repo
    end
  end
end
```

Alternatively, you can `use` the testing module in individual tests if you'd
prefer not to include helpers in _every_ test.

```elixir
defmodule MyApp.WorkerTest do
  use MyApp.Case, async: true

  use Styx.Testing, repo: MyApp.Repo
end
```

Whichever way you choose, using `use Styx.Testing` requires the `repo` option
because it's injected into many of the generated helpers.

If you are using isolation with namespaces through PostgreSQL schemas (Ecto
"prefixes"), you can also specify this prefix when using `Styx.Testing`:

```elixir
use Styx.Testing, repo: MyApp.Repo, prefix: "private"
```

With Styx configured for testing and helpers in the appropriate places, you're
ready for testing. Learn about unit testing with [Testing Workers][tw],
integration testing with [Testing Queues][tq], or prepare for production with
[Testing Config][tc].

[tw]: testing_workers.html
[tq]: testing_queues.html
[tc]: testing_config.html
