defmodule Styx.MigrationTest do
  use ExUnit.Case, async: true

  defmodule CustomAdapter do
  end

  defmodule CustomMigrator do
    def current_version, do: 42
    def migrated_version(_opts), do: 42
  end

  defmodule CustomRepo do
    def __adapter__, do: CustomAdapter
    def config, do: [migrator: CustomMigrator]
  end

  defmodule OutdatedMigrator do
    def current_version, do: 2
    def migrated_version(_opts), do: 1
  end

  defmodule OutdatedRepo do
    def __adapter__, do: CustomAdapter
    def config, do: [migrator: OutdatedMigrator]
  end

  test "uses the configured custom migrator when verifying migrations" do
    assert :ok = Styx.Migration.verify_migrated!(repo: CustomRepo)
  end

  test "raises when migrations are outdated" do
    assert_raise RuntimeError, ~r/migrations are outdated/, fn ->
      Styx.Migration.verify_migrated!(repo: OutdatedRepo)
    end
  end
end
