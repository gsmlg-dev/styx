defmodule Styx.Test.Repo.Postgres.Migrations.AddStyxJobsTable do
  use Ecto.Migration

  def up do
    Styx.Migrations.up(unlogged: false)
    Styx.Migrations.up(prefix: "private", unlogged: false)
  end

  def down do
    Styx.Migrations.down(prefix: "private", version: 1)
    Styx.Migrations.down(version: 1)
  end
end
