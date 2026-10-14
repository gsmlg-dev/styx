defmodule Styx.Migrations.MyXQLTest do
  use Styx.Case, async: true

  defmodule MigrationRepo do
    @moduledoc false

    use Ecto.Repo, otp_app: :styx, adapter: Ecto.Adapters.MyXQL

    alias Styx.Test.DolphinRepo

    def init(_, _) do
      opts =
        DolphinRepo.config()
        |> Keyword.put(:database, "oban_migrations")
        |> Keyword.delete(:pool)

      {:ok, opts}
    end
  end

  @moduletag :dolphin

  defmodule Migration do
    use Ecto.Migration

    def up do
      Styx.Migration.up()
    end

    def down do
      Styx.Migration.down()
    end
  end

  defp storage_up(_conf) do
    MigrationRepo.__adapter__().storage_up(MigrationRepo.config())
  end

  defp storage_down do
    MigrationRepo.__adapter__().storage_down(MigrationRepo.config())
  end

  setup :storage_up

  test "verifying that any migrations have ran" do
    start_supervised!(MigrationRepo)

    assert_raise RuntimeError, ~r/migrations have not been run/, fn ->
      start_supervised_oban!(repo: MigrationRepo, testing: :manual)
    end
  after
    storage_down()
  end

  test "migrating a mysql database" do
    start_supervised!(MigrationRepo)

    assert :ok = Ecto.Migrator.up(MigrationRepo, 1, Migration)
    assert table_exists?("oban_jobs")
    assert table_exists?("oban_peers")

    assert :ok = Ecto.Migrator.down(MigrationRepo, 1, Migration)
    refute table_exists?("oban_jobs")
    refute table_exists?("oban_peers")
  after
    storage_down()
  end

  defp table_exists?(name) do
    query = """
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = 'oban_migrations'
      AND TABLE_NAME = '#{name}'
    )
    """

    {:ok, %{rows: [[exists]]}} = MigrationRepo.query(query)

    exists != 0
  end
end
