defmodule Styx.Test.Exercise do
  @moduledoc false

  alias Ecto.Multi
  alias Styx.Job

  defmodule Used do
    @moduledoc false

    use Styx, otp_app: :styx
  end

  def check_used do
    changeset = changeset()

    {:ok, _} = Used.insert(changeset)
    {:ok, _} = Used.insert(changeset, timeout: 500)

    %Multi{} = Used.insert(Multi.new(), :job, changeset)
    %Multi{} = Used.insert(Multi.new(), :job, changeset, timeout: 500)
  end

  def check_insert do
    changeset = changeset()

    {:ok, _} = Styx.insert(changeset)
    {:ok, _} = Styx.insert(Styx, changeset)
    {:ok, _} = Styx.insert(changeset, timeout: 500)
    {:ok, _} = Styx.insert(Styx, changeset, timeout: 500)

    %Multi{} = Styx.insert(Multi.new(), :job, changeset)
    %Multi{} = Styx.insert(Multi.new(), :job, changeset, timeout: 500)
    %Multi{} = Styx.insert(Styx, Multi.new(), :job, changeset)
    %Multi{} = Styx.insert(Styx, Multi.new(), :job, changeset, timeout: 500)
  end

  def check_insert_all do
    changeset = changeset()
    stream = Stream.duplicate(changeset, 1)
    wrapper = %{changesets: [changeset]}

    [_ | _] = Styx.insert_all([changeset])
    [_ | _] = Styx.insert_all(Styx, [changeset])
    [_ | _] = Styx.insert_all([changeset], timeout: 500)
    [_ | _] = Styx.insert_all(Styx, [changeset], timeout: 500)

    [_ | _] = Styx.insert_all(stream)
    [_ | _] = Styx.insert_all(Styx, stream)
    [_ | _] = Styx.insert_all(stream, timeout: 500)
    [_ | _] = Styx.insert_all(Styx, stream, timeout: 500)

    [_ | _] = Styx.insert_all(wrapper)
    [_ | _] = Styx.insert_all(Styx, wrapper)
    [_ | _] = Styx.insert_all(wrapper, timeout: 500)
    [_ | _] = Styx.insert_all(Styx, wrapper, timeout: 500)

    %Multi{} = Styx.insert_all(Multi.new(), :job, [changeset])
    %Multi{} = Styx.insert_all(Multi.new(), :job, [changeset], timeout: 500)
    %Multi{} = Styx.insert_all(Styx, Multi.new(), :job, [changeset])
    %Multi{} = Styx.insert_all(Styx, Multi.new(), :job, [changeset], timeout: 500)
  end

  def check_pause_resume_all do
    Styx.pause_all_queues()
    Styx.pause_all_queues(Styx)
    Styx.pause_all_queues(Styx, local_only: true)
    Styx.pause_all_queues(local_only: true)

    Styx.resume_all_queues()
    Styx.resume_all_queues(Styx)
    Styx.resume_all_queues(Styx, local_only: true)
    Styx.resume_all_queues(local_only: true)
  end

  defp changeset, do: Job.new(%{}, worker: "FakeWorker")
end
