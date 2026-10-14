defmodule Styx.Test.XQLRepo.Migrations.AddStyxJobsTable do
  use Ecto.Migration

  defdelegate up, to: Styx.Migration
  defdelegate down, to: Styx.Migration
end
