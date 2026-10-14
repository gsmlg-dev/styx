# Instance and Database Isolation

This guide will walk you through options for isolating Styx instances as well as Styx database
tables.

## Running Multiple Styx Instances

You can run multiple Styx instances with different prefixes on the same system and have them
entirely isolated, provided you give each Styx supervisor a distinct name. You can do this in one
of two ways: explicit names or **facades**.

### Facades

You can create an [Styx **facade**](`Styx.__using__/1`) by defining a module that calls `use
Styx`:

```elixir
defmodule MyApp.StyxA do
  use Styx, otp_app: :my_app
end

defmodule MyApp.StyxB do
  use Styx, otp_app: :my_app
end
```

Configure facades through the application environment, for example in `config/config.exs`:

```elixir
config :my_app, MyApp.StyxA, repo: MyAppo.Repo, prefix: "special"
config :my_app, MyApp.StyxB, repo: MyAppo.Repo, prefix: "private"
```

You can then start these facades in your application's supervision tree:

```elixir
@impl true
def start(_type, _args) do
  children = [
    MyApp.Repo,
    MyApp.StyxA,
    MyApp.StyxB
  ]

  Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
end
```

Styx facades define all the functions that the `Styx` module defines, so use the facade in place
of `Styx`:

```elixir
MyApp.StyxA.insert(MyApp.Worker.new(%{}))
```

### Isolated Instances Via Names

Here we configure our application to start three Styx supervisors using the `"public"` (default),
`"special"`, and `"private"` prefixes, respectively:

```elixir
def start(_type, _args) do
  children = [
    MyApp.Repo,
    {Styx, name: StyxA, repo: MyApp.Repo},
    {Styx, name: StyxB, repo: MyApp.Repo, prefix: "special"},
    {Styx, name: StyxC, repo: MyApp.Repo, prefix: "private"}
  ]

  Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
end
```

When you do this, you'll have to use the correct Styx supervisor name when performing Styx-related
operations. You'll see that most functions in the `Styx` module, for example, take an optional
first argument which represents the name of the Styx supervisor. By default, that's `Styx`, which
is why this works if you don't explicitly start an Styx supervisor in your application:

```elixir
Styx.insert(MyApp.Worker.new(%{}))
```

In the example above, with `StyxA`/`StyxB`/`StyxC`, you can specify which Styx instance you want
to use for scheduling by passing its name in:

```elixir
Styx.insert(StyxB, MyApp.Worker.new(%{}))
```

### Umbrella Apps

If you need to run Styx from an umbrella application where more than one of the child apps need to
interact with Styx, you may need to set the `:name` for each child application that configures
Styx.

For example, your umbrella contains two apps: `MyAppA` and `MyAppB`. `MyAppA` is responsible for
inserting jobs, while only `MyAppB` actually runs any queues.

Configure Styx with a custom name for `MyAppA`:

```elixir
config :my_app_a, Styx,
  name: MyAppA.Styx,
  repo: MyApp.Repo
```

Then configure Styx for `MyAppB` with a different name and different options:

```elixir
config :my_app_b, Styx,
  name: MyAppB.Styx,
  repo: MyApp.Repo,
  queues: [default: 10]
```

Now, use the configured name when calling functions like `Styx.insert/2`, `Styx.insert_all/2`,
`Styx.drain_queue/2`, and so on, to reference the correct Styx process for the current
application.

```elixir
Styx.insert(MyAppA.Styx, MyWorker.new(%{}))
Styx.insert_all(MyAppB.Styx, multi, :multiname, [MyWorker.new(%{})])
Styx.drain_queue(MyAppB.Styx, queue: :default)
```

## Database Isolation

Let's look at a few options for isolating or scoping Styx database queries.

### Database Prefixes

Styx supports namespacing through **PostgreSQL schemas**, also called "prefixes" in Ecto. With
prefixes, your job table can reside outside of your primary schema (usually `public`) and you can
have multiple separate job tables.

To use a prefix you first have to specify it within your migration:

```elixir
defmodule MyApp.Repo.Migrations.AddPrefixedObanJobsTable do
  use Ecto.Migration

  def up do
    Styx.Migrations.up(prefix: "private")
  end

  def down do
    Styx.Migrations.down(prefix: "private")
  end
end
```

The migration will create the `private` schema and all Styx-related tables within that schema.
With the database migrated, you'll then specify the prefix in your configuration:

```elixir
config :my_app, Styx,
  prefix: "private",
  repo: MyApp.Repo,
  queues: [default: 10]
```

Now all jobs are inserted and executed using the `private.oban_jobs` table. Note that while
`Styx.insert/2,4` will write jobs in the `private.oban_jobs` table automatically, you'll need to
specify a prefix *manually* if you insert jobs directly through a repo.

Not only is the `oban_jobs` table isolated within the schema, but all notification events are also
isolated. That means that insert/update events will only dispatch new jobs for their prefix.

### Dynamic Repositories

Styx supports [Ecto dynamic repositories][dynamic] through the repo's `:dynamic_repo` option. To
make this work, you need to run a separate Styx instance for each dynamic repo instance. Most often
it's worth bundling each Styx and repo instance under the same supervisor:

```elixir
def start_repo_and_styx(instance_id) do
  children = [
    {MyDynamicRepo, name: nil, url: repo_url(instance_id)},
    {Styx, name: instance_id, repo: {MyDynamicRepo, dynamic_repo: fn -> repo_pid(instance_id) end}}
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

The function `repo_pid/1` in this example must return the PID of the repo for the given instance.
You can use `Registry` to register the repo (for example in the repo's `init/2` callback) and
discover it.

If your application exclusively uses dynamic repositories and doesn't specify all credentials
upfront, you must implement a `init/1` callback in your Ecto repo. Doing so provides the Postgres
notifier with the correct credentials on initialization, allowing jobs to process as expected.

### Ecto Multi-tenancy

If you followed the Ecto guide on setting up multi-tenancy with foreign keys, you need to add an
exception for queries originating from Styx. All of Styx's queries have the custom option `styx:
true` to help you identify them in `prepare_query/3` or other instrumentation:

```elixir
# Sample code, only relevant if you followed the Ecto guide on multi tenancy with foreign keys.
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app

  require Ecto.Query

  @impl true
  def prepare_query(_operation, query, opts) do
    cond do
      opts[:skip_org_id] || opts[:schema_migration] || opts[:styx] ->
        {query, opts}

      org_id = opts[:org_id] ->
        {Ecto.Query.where(query, org_id: ^org_id), opts}

      true ->
        raise "expected org_id or skip_org_id to be set"
    end
  end
end
```

[dynamic]: https://ecto.hexdocs.pm/replicas-and-dynamic-repositories.html#dynamic-repositories
