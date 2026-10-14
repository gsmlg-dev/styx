defmodule BenchHelper do
  alias Styx.Test.{LiteRepo, Repo}

  def start do
    Application.ensure_all_started(:postgrex)
    Repo.start_link()
    LiteRepo.start_link()

    reset_db()
  end

  def reset_db do
    Repo.query!("TRUNCATE styx_jobs", [], log: false)
    LiteRepo.query!("DELETE FROM styx_jobs", [], log: false)
  end

  def term_to_base64(term) do
    term
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  def base64_to_term(bin) do
    bin
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end
end

BenchHelper.start()
