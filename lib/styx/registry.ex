defmodule Styx.Registry do
  @moduledoc """
  Local process storage for Styx instances.
  """

  @type role :: term()
  @type key :: Styx.name() | {Styx.name(), role()}
  @type value :: term()

  @doc false
  def child_spec(_arg) do
    [keys: :unique, name: __MODULE__]
    |> Registry.child_spec()
    |> Supervisor.child_spec(id: __MODULE__)
  end

  @doc """
  Fetch the config for an Styx supervisor instance.

  ## Example

  Get the default instance config:

      Styx.Registry.config(Styx)

  Get config for a custom named instance:

      Styx.Registry.config(MyApp.Styx)
  """
  @spec config(Styx.name()) :: Styx.Config.t()
  def config(styx_name) do
    case lookup(styx_name) do
      {_pid, config} ->
        config

      _ ->
        raise RuntimeError, """
        No Styx instance named `#{inspect(styx_name)}` is running and config isn't available.
        """
    end
  end

  @doc """
  Find the `{pid, value}` pair for a registered Styx process.

  ## Example

  Get the default instance config:

      Styx.Registry.lookup(Styx)

  Get a supervised module's pid:

      Styx.Registry.lookup(Styx, Styx.Notifier)
  """
  @spec lookup(Styx.name(), role()) :: nil | {pid(), value()}
  def lookup(styx_name, role \\ nil) do
    __MODULE__
    |> Registry.lookup(key(styx_name, role))
    |> List.first()
  end

  @doc """
  Select details of registered Styx processes using a full match spec.

  ## Example

  Get a list of all running Styx instances:

      Styx.Registry.select([{{:"$1", :_, :_}, [{:is_atom, :"$1"}], [:"$1"]}])
  """
  @spec select(Registry.spec()) :: [term()]
  def select(spec) do
    Registry.select(__MODULE__, spec)
  end

  @doc """
  Returns the pid of a supervised Styx process, or `nil` if the process can't be found.

  ## Example

  Get the Styx supervisor's pid:

      Styx.Registry.whereis(Styx)

  Get a supervised module's pid:

      Styx.Registry.whereis(Styx, Styx.Notifier)

  Get the pid for a plugin:

      Styx.Registry.whereis(Styx, {:plugin, MyApp.Styx.Plugin})

  Get the pid for a queue's producer:

      Styx.Registry.whereis(Styx, {:producer, "default"})
  """
  @spec whereis(Styx.name(), role()) :: pid() | {atom(), node()} | nil
  def whereis(styx_name, role \\ nil) do
    styx_name
    |> via(role)
    |> GenServer.whereis()
  end

  @doc """
  Build a via tuple suitable for calls to a supervised Styx process.

  ## Example

  For an Styx supervisor:

      Styx.Registry.via(Styx)

  For a supervised module:

      Styx.Registry.via(Styx, Styx.Notifier)

  For a plugin:

      Styx.Registry.via(Styx, {:plugin, Styx.Cron})
  """
  @spec via(Styx.name(), role(), value()) :: {:via, Registry, {__MODULE__, key()}}
  def via(styx_name, role \\ nil, value \\ nil)
  def via(styx_name, role, nil), do: {:via, Registry, {__MODULE__, key(styx_name, role)}}
  def via(styx_name, role, value), do: {:via, Registry, {__MODULE__, key(styx_name, role), value}}

  defp key(styx_name, nil), do: styx_name
  defp key(styx_name, role), do: {styx_name, role}
end
