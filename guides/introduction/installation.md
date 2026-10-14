# Installation

Before starting ensure your application has Ecto configured to use [Postgrex][postgrex] for
Postgres, [EctoSQLite3][ecto_sqlite3] for SQLite3, or [MyXQL][myxql] for use with MySQL.

There are three installation mechanisms available:

* [Semi-Automatic Installation](#semi-automatic-installation) using an igniter powered mix task
* [Igniter Installation](#igniter-installation) fully automatic installation using igniter
* [Manual Installation](#manual-installation) add styx and handle all steps manually

## Semi-Automatic Installation

It's possible to use the `styx.install` task without the `igniter.install` escript available.
First, add `styx` and `igniter` to your deps in `mix.exs`:

```elixir
{:styx, "~> 0.1"},
{:igniter, "~> 0.5", only: [:dev]},
```

Run `mix deps.get` to fetch `styx`, then run the install task:

```bash
mix styx.install
```

That will automate all of the manual steps listed below!

## Igniter Installation

For projects that have [igniter][igniter] available, Styx may be installed and configured with a
single command:

```bash
mix igniter.install styx
```

That will add the latest version of `styx` to your dependencies before running the installer.
Installation will use the application's default Ecto repo, select the corresponding engine, and
set the pubsub notifier accordingly.

Use the `--repo` flag to specify an alternate repo manually:

```bash
mix igniter.install styx --repo MyApp.LiteRepo
```

## Manual Installation

Add `:styx` to your list of deps in `mix.exs`:

```elixir
{:styx, "~> 0.1"}
```

Then run `mix deps.get` to install Styx and its dependencies. After the packages are installed you
must create a database migration to add the `oban_jobs` table to your database:

```bash
mix ecto.gen.migration add_oban_jobs_table
```

Open the generated migration in your editor and call the `up` and `down` functions on
`Styx.Migration`:

```elixir
defmodule MyApp.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up do
    Styx.Migration.up(version: 14)
  end

  # We specify `version: 1` in `down`, ensuring that we'll roll all the way back down if
  # necessary, regardless of which version we've migrated `up` to.
  def down do
    Styx.Migration.down(version: 1)
  end
end
```

This will run all of Styx's versioned migrations for your database. Migrations between versions
are idempotent and rarely change after a release. As new versions are released you may need to run
additional migrations.

Now, run the migration to create the table:

```bash
mix ecto.migrate
```

Before you can run an Styx instance you must provide some base configuration:

<!-- tabs-open -->

### Postgres

Running with Postgres requires using the `Styx.Engines.Basic` engine:

```elixir
# config/config.exs
config :my_app, Styx,
  engine: Styx.Engines.Basic,
  queues: [default: 10],
  lifeline: [rescue_after: {2, :hours}],
  pruner: [max_age: {1, :day}],
  repo: MyApp.Repo
```

### SQLite3

Running with SQLite3 requires using the `Styx.Engines.Lite` engine:

```elixir
# config/config.exs
config :my_app, Styx,
  engine: Styx.Engines.Lite,
  queues: [default: 10],
  lifeline: [rescue_after: {2, :hours}],
  pruner: [max_age: {1, :day}],
  repo: MyApp.Repo
```

### MySQL

Running with MySQL requires using the `Styx.Engines.Dolphin` engine:

```elixir
# config/config.exs
config :my_app, Styx,
  engine: Styx.Engines.Dolphin,
  queues: [default: 10],
  lifeline: [rescue_after: {2, :hours}],
  pruner: [max_age: {1, :day}],
  repo: MyApp.Repo
```

<!-- tabs-close -->

To prevent Styx from running jobs and plugins during test runs, enable `:testing` mode in
`test.exs`:

```elixir
# config/test.exs
config :my_app, Styx, testing: :manual
```

Styx instances are isolated supervision trees and must be included in your application's
supervisor to run. Use the application configuration you've just set and include Styx in the list
of supervised children:

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = [
    MyApp.Repo,
    {Styx, Application.fetch_env!(:my_app, Styx)}
  ]

  Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
end
```

Finally, verify that Styx is configured and running properly. Within a new `iex -S mix` session:

```elixir
iex(1)> Styx.config()
#=> %Styx.Config{repo: MyApp.Repo}
```

You're all set! Add the [Styx Web][web] dashboard for monitoring, get started creating jobs and
configuring queues in [Usage][use], or head to the [testing guide][test] to learn how to test with
Styx.

[use]: Styx.html#Usage
[web]: https://github.com/oban-bg/oban_web
[igniter]: https://hex.pm/packages/igniter
[test]: testing.md
[postgrex]: https://hex.pm/packages/postgrex
[ecto_sqlite3]: https://hex.pm/packages/ecto_sqlite3
[myxql]: https://hex.pm/packages/myxql
