defmodule Mix.Tasks.Styx.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  @moduletag :igniter

  describe "install" do
    test "installing without an available ecto repo" do
      assert {:error, [warning]} =
               test_project()
               |> Igniter.compose_task("styx.install", [])
               |> apply_igniter()

      assert warning =~ "No ecto repos found for :test"
    end

    test "installing with an ecto repo available" do
      application = """
      defmodule Styx.Application do
        use Application

        def start(_type, _args) do
          children = [
            Styx.Test.Repo,
            {Ecto.Migrator, migrator_opts()},
            MyWeb.Endpoint
          ]
        end
      end
      """

      repo = """
      defmodule Styx.Test.Repo do
        @moduledoc false

        use MyApp.CustomMacro, otp_app: :styx

        use Ecto.Repo, otp_app: :styx, adapter: Ecto.Adapters.Postgres
      end
      """

      files = %{"lib/styx/application.ex" => application, "lib/styx/repo.ex" => repo}

      [app_name: :styx, files: files]
      |> test_project()
      |> Igniter.compose_task("styx.install", [])
      |> assert_has_patch("config/config.exs", """
        | config :styx, Styx,
        |   engine: Styx.Engines.Basic,
        |   notifier: Styx.Notifiers.Postgres,
        |   queues: [default: 10],
        |   lifeline: [rescue_after: {2, :hours}],
        |   pruner: [max_age: {1, :day}],
        |   repo: Styx.Test.Repo
      """)
      |> assert_has_patch("config/test.exs", """
        | config :styx, Styx, testing: :manual
      """)
      |> assert_has_patch("lib/styx/application.ex", """
        | {Styx, Application.fetch_env!(:styx, Styx)},
        | MyWeb.Endpoint
      """)
    end

    test "installing with an ash_postgres repo available" do
      application = """
      defmodule Styx.Application do
        use Application

        def start(_type, _args) do
          children = [
            Styx.Test.Repo,
            {Ecto.Migrator, migrator_opts()},
            MyWeb.Endpoint
          ]
        end
      end
      """

      repo = """
      defmodule Styx.Test.Repo do
        @moduledoc false

        use MyApp.CustomMacro, otp_app: :styx

        use AshPostgres.Repo, otp_app: :styx
      end
      """

      files = %{"lib/styx/application.ex" => application, "lib/styx/repo.ex" => repo}

      [app_name: :styx, files: files]
      |> test_project()
      |> Igniter.compose_task("styx.install", [])
      |> assert_has_patch("config/config.exs", """
        | config :styx, Styx,
        |   engine: Styx.Engines.Basic,
        |   notifier: Styx.Notifiers.Postgres,
        |   queues: [default: 10],
        |   lifeline: [rescue_after: {2, :hours}],
        |   pruner: [max_age: {1, :day}],
        |   repo: Styx.Test.Repo
      """)
      |> assert_has_patch("config/test.exs", """
        | config :styx, Styx, testing: :manual
      """)
      |> assert_has_patch("lib/styx/application.ex", """
        | {Styx, Application.fetch_env!(:styx, Styx)},
        | MyWeb.Endpoint
      """)
    end

    test "installing doesnt override existing config" do
      repo = """
      defmodule Styx.Test.LiteRepo do
        @moduledoc false

        use Ecto.Repo, otp_app: :styx, adapter: Ecto.Adapters.SQLite3
      end
      """

      conf_code = [engine: :foo, notifier: :bar, queues: [foobar: 10], repo: :repo]
      test_code = [testing: :is_awesome]

      [app_name: :styx, files: %{"lib/styx/repo.ex" => repo}]
      |> test_project()
      |> Igniter.Project.Config.configure("config.exs", :styx, [Styx], {:code, conf_code})
      |> Igniter.Project.Config.configure("test.exs", :styx, [Styx], {:code, test_code})
      |> apply_igniter!()
      |> Igniter.compose_task("styx.install", ["--repo", "Styx.Test.LiteRepo"])
      |> assert_unchanged("config/config.exs")
      |> assert_unchanged("config/test.exs")
    end

    test "installing selects correct config with alternate repo" do
      repo = """
      defmodule Styx.Test.LiteRepo do
        @moduledoc false

        use Ecto.Repo, otp_app: :styx, adapter: Ecto.Adapters.SQLite3
      end
      """

      [app_name: :styx, files: %{"lib/styx/repo.ex" => repo}]
      |> test_project()
      |> Igniter.compose_task("styx.install", ["--repo", "Styx.Test.LiteRepo"])
      |> assert_has_patch("config/config.exs", """
        | config :styx, Styx,
        |   engine: Styx.Engines.Lite,
        |   notifier: Styx.Notifiers.PG,
        |   queues: [default: 10],
        |   lifeline: [rescue_after: {2, :hours}],
        |   pruner: [max_age: {1, :day}],
        |   repo: Styx.Test.LiteRepo
      """)
    end

    test "installing with an unsupported adapter repos shows an error" do
      repo = """
      defmodule Styx.Test.TdsRepo do
        @moduledoc false

        use Ecto.Repo, otp_app: :styx, adapter: Ecto.Adapters.Tds
      end
      """

      assert {:error, [warning]} =
               [app_name: :styx, files: %{"lib/styx/repo.ex" => repo}]
               |> test_project()
               |> Igniter.compose_task("styx.install", [])
               |> apply_igniter()

      assert warning =~ "No compatible Ecto repo found"
    end

    test "installing skips unsupported adapter and uses supported repo" do
      application = """
      defmodule Styx.Application do
        use Application

        def start(_type, _args) do
          children = [Styx.Test.TdsRepo, Styx.Test.Repo, MyWeb.Endpoint]
        end
      end
      """

      tds_repo = """
      defmodule Styx.Test.TdsRepo do
        @moduledoc false

        use Ecto.Repo, otp_app: :styx, adapter: Ecto.Adapters.Tds
      end
      """

      postgres_repo = """
      defmodule Styx.Test.Repo do
        @moduledoc false

        use Ecto.Repo, otp_app: :styx, adapter: Ecto.Adapters.Postgres
      end
      """

      files = %{
        "lib/styx/application.ex" => application,
        "lib/styx/tds_repo.ex" => tds_repo,
        "lib/styx/repo.ex" => postgres_repo
      }

      [app_name: :styx, files: files]
      |> test_project()
      |> Igniter.compose_task("styx.install", [])
      |> assert_has_patch("config/config.exs", """
        | config :styx, Styx,
        |   engine: Styx.Engines.Basic,
        |   notifier: Styx.Notifiers.Postgres,
        |   queues: [default: 10],
        |   lifeline: [rescue_after: {2, :hours}],
        |   pruner: [max_age: {1, :day}],
        |   repo: Styx.Test.Repo
      """)
    end
  end
end
