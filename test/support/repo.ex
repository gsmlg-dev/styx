defmodule Styx.Test.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :styx,
    adapter: Ecto.Adapters.Postgres
end

defmodule Styx.Test.DynamicRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :styx,
    adapter: Ecto.Adapters.Postgres

  def use_dynamic_repo(pid) do
    pid
  end

  def init(_, _) do
    {:ok, Styx.Test.Repo.config()}
  end
end

defmodule Styx.Test.LiteRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :styx, adapter: Ecto.Adapters.SQLite3
end

defmodule Styx.Test.DolphinRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :styx, adapter: Ecto.Adapters.MyXQL
end

defmodule Styx.Test.UnboxedRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :styx,
    adapter: Ecto.Adapters.Postgres

  def init(_, _) do
    config = Styx.Test.Repo.config()

    {:ok, Keyword.delete(config, :pool)}
  end
end
