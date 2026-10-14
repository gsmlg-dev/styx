defmodule Styx.Engines.BasicTest do
  use Styx.Case, async: true

  test "inserting jobs with a custom prefix" do
    name = start_supervised_styx!(prefix: "private")

    Styx.insert!(name, Worker.new(%{ref: 1, action: "OK"}))

    assert [%Job{}] = Repo.all(Job, prefix: "private")
  end

  test "inserting unique jobs with a custom prefix" do
    name = start_supervised_styx!(prefix: "private")
    opts = [unique: [period: 60, fields: [:worker]]]

    Styx.insert!(name, Worker.new(%{ref: 1, action: "OK"}, opts))
    Styx.insert!(name, Worker.new(%{ref: 2, action: "OK"}, opts))

    assert [%Job{args: %{"ref" => 1}}] = Repo.all(Job, prefix: "private")
  end
end
