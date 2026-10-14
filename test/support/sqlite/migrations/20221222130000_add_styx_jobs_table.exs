defmodule Styx.Test.Repo.SQLite.Migrations.AddStyxJobsTable do
  use Ecto.Migration

  defdelegate up, to: Styx.Migration
  defdelegate down, to: Styx.Migration
end
