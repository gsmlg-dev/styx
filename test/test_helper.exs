Application.ensure_all_started(:postgrex)

Styx.Test.Repo.start_link()
Styx.Test.DolphinRepo.start_link()
Styx.Test.LiteRepo.start_link()
Styx.Test.UnboxedRepo.start_link()
ExUnit.start(assert_receive_timeout: 2_000, refute_receive_timeout: 50, exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(Styx.Test.DolphinRepo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Styx.Test.Repo, :manual)

:pg.start_link(Styx.Notifiers.PG)
