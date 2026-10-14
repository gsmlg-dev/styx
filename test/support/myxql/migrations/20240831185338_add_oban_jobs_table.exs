defmodule Styx.Test.XQLRepo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  defdelegate up, to: Styx.Migration
  defdelegate down, to: Styx.Migration
end
