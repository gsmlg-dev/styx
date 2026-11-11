defmodule Styx.Engines.BasicRateLimitTest do
  use Styx.Case, async: true

  @moduletag :capture_log

  defp start_rate_limited!(rate_limit) do
    start_supervised_styx!(
      queues: [alpha: [limit: 5, rate_limit: rate_limit]],
      stager: [interval: 5],
      testing: :disabled
    )
  end

  defp insert_jobs!(name, refs) do
    for ref <- refs, do: Styx.insert!(name, Worker.new(%{action: "OK", ref: ref}))
  end

  test "starts no more jobs than allowed within the window" do
    name = start_rate_limited!(allowed: 2, period: 60)

    insert_jobs!(name, 1..5)

    assert_receive {:ok, first}
    assert_receive {:ok, second}
    refute_receive {:ok, _third}, 300

    assert Enum.sort([first, second]) == [1, 2]

    available =
      name
      |> Styx.config()
      |> Styx.Repo.all(Job)
      |> Enum.count(&(&1.state == "available"))

    assert available == 3
  end

  test "starts held back jobs once the window has passed" do
    name = start_rate_limited!(allowed: 1, period: 1)

    insert_jobs!(name, 1..2)

    assert_receive {:ok, 1}
    started = System.monotonic_time(:millisecond)

    assert_receive {:ok, 2}, 3_000
    assert System.monotonic_time(:millisecond) - started >= 800
  end

  test "the window counts jobs attempted before this producer started" do
    name = start_rate_limited!(allowed: 1, period: 60)

    conf = Styx.config(name)
    recent = DateTime.add(DateTime.utc_now(), -10, :second)

    Styx.Repo.insert!(conf, %Job{
      worker: inspect(Worker),
      queue: "alpha",
      args: %{},
      state: "completed",
      attempt: 1,
      attempted_at: recent,
      completed_at: recent
    })

    insert_jobs!(name, [1])

    refute_receive {:ok, 1}, 300
  end
end
