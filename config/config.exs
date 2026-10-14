import Config

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :logger, level: :warning

config :styx, Styx.Backoff, retry_mult: 1

config :styx, Styx.Repo,
  retry_opts: [
    delay: 10,
    expected_delay: 5,
    expected_retry: 2,
    retry: 2
  ]

config :styx, Styx.Test.Repo,
  migration_lock: false,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  priv: "test/support/postgres",
  show_sensitive_data_on_connection_error: true,
  stacktrace: true,
  url: System.get_env("POSTGRES_URL") || "postgres://localhost:5432/styx_test"

config :styx, Styx.Test.LiteRepo,
  database: "priv/styx.db",
  priv: "test/support/sqlite",
  stacktrace: true,
  temp_store: :memory

config :styx, Styx.Test.DolphinRepo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  priv: "test/support/myxql",
  show_sensitive_data_on_connection_error: true,
  stacktrace: true,
  url: System.get_env("MYSQL_URL") || "mysql://root@localhost:3306/styx_test"

config :styx,
  ecto_repos: [Styx.Test.Repo, Styx.Test.LiteRepo, Styx.Test.DolphinRepo]
