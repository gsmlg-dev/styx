# Testing Config

An Styx instance's config is built from options passed to `Styx.start_link`
during initialization and it determines the supervision tree that Styx builds.
The instance config is encapsulated by an `Styx.Config` struct, which is then
referenced by plugins, queues, and most public functions.

## Testing Dynamic Config

Styx automatically normalizes and validates config options on initialization.
That covers any static configuration, but it won't help when config is generated
dynamically, at runtime.

The `Styx.Config.validate/1` helper is used internally when the config
initializes. Along with each top level option, like the `:engine` or `:repo`, it
recursively verifies all queue and plugin options.

You can use `validate/1` to verify dynamic configuration, e.g. options specified
in `runtime.exs`:

```elixir
test "production styx config is valid" do
  config =
    "config/config.exs"
    |> Config.Reader.read!(env: :prod)
    |> get_in([:my_app, Styx])

  assert :ok = Styx.Config.validate(config)
end
```

When the configuration contains **any** invalid options, like an invalid engine,
you'll see the test fail with an error like this:

```elixir
{:error, "expected :engine to implement Styx.Engine, got: MyApp.Repo"}
```

## Testing Dynamic Plugin Config

Validation is especially helpful for plugins that have complex configuration,
e.g. `Cron`. All plugins implement the `c:Styx.Plugin.validate/1` callback and we can test them
in isolation as well as through the top level config.

Suppose you have a helper function that returns a crontab config at runtime:

```elixir
defmodule MyApp.Styx do
  def cron_config do
    [crontab: [{"0 24 * * *", MyApp.Worker}]]
  end
end
```

You can call that function within a test and then assert that it is valid with
`c:Styx.Plugin.validate/1`:

```elixir
test "testing cron plugin configuration" do
  config = MyApp.Styx.cron_config()

  assert :ok = Styx.Cron.validate(config)
end
```

Running this test will return an error tuple, showing that the cron expression
isn't valid.

```elixir
{:error, %ArgumentError{message: "expression field 24 is out of range 0..23"}}
```

Switch the expression from `0 24 * * *` to `0 23 * * *`, run the tests again,
and everything passes!
