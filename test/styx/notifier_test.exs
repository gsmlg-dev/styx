for notifier <- [Styx.Notifiers.Isolated, Styx.Notifiers.PG, Styx.Notifiers.Postgres] do
  defmodule Module.concat(notifier, Test) do
    use Styx.Case, async: true

    alias Styx.{Config, Notifier}

    @notifier notifier

    describe "with #{inspect(notifier)}" do
      test "broadcasting notifications to subscribers" do
        name = start_styx!()
        ident = to_ident(name)

        await_joined(name)

        :ok = Notifier.listen(name, :signal)
        :ok = Notifier.notify(name, :signal, %{incoming: "message", ident: ident})

        assert_receive {:notification, :signal, %{"incoming" => "message"}}
      end

      test "returning an error without a live notifier process" do
        conf = Config.new(name: make_ref(), repo: UnboxedRepo, notifier: @notifier)

        assert {:error, %RuntimeError{}} = Notifier.notify(conf, :signal, %{})
      end

      test "notifying with complex types" do
        name = start_styx!()
        ident = to_ident(name)

        await_joined(name)

        Notifier.listen(name, [:insert, :gossip, :signal])

        Notifier.notify(name, :signal, %{
          date: ~D[2021-08-09],
          keyword: [a: 1, b: 1],
          map: %{tuple: {1, :second}},
          tuple: {1, :second},
          ident: ident
        })

        assert_receive {:notification, :signal, %{"date" => _} = notice}
        assert %{"date" => "2021-08-09", "keyword" => [["a", 1], ["b", 1]]} = notice
        assert %{"map" => %{"tuple" => [1, "second"]}, "tuple" => [1, "second"]} = notice
      end

      test "broadcasting on select channels" do
        name = start_styx!()
        ident = to_ident(name)

        await_joined(name)

        :ok = Notifier.listen(name, [:signal, :gossip])
        :ok = Notifier.unlisten(name, [:gossip])

        :ok = Notifier.notify(name, :gossip, %{foo: "bar", ident: ident})
        :ok = Notifier.notify(name, :signal, %{baz: "bat", ident: ident})

        assert_receive {:notification, :signal, _}
        refute_received {:notification, :gossip, _}
      end

      test "ignoring messages scoped to other instances" do
        name = start_styx!()
        ident = to_ident(name)

        await_joined(name)

        :ok = Notifier.listen(name, [:gossip, :signal])

        :ok = Notifier.notify(name, :gossip, %{foo: "bar", ident: ident})
        :ok = Notifier.notify(name, :signal, %{foo: "baz", ident: "bogus.ident"})

        assert_receive {:notification, :gossip, %{"foo" => "bar"}}
        refute_received {:notification, :signal, %{"foo" => "baz"}}
      end
    end

    test "repeated listen calls don't deliver multiple notifications" do
      name = start_styx!()
      ident = to_ident(name)

      await_joined(name)

      :ok = Notifier.listen(name, :signal)
      :ok = Notifier.listen(name, :signal)
      :ok = Notifier.notify(name, :signal, %{value: "once", ident: ident})

      assert_receive {:notification, :signal, %{"value" => "once"}}
      refute_received {:notification, :signal, _}
    end

    test "listeners stop receiving notifications after unlisten" do
      name = start_styx!()
      ident = to_ident(name)

      await_joined(name)

      :ok = Notifier.listen(name, [:signal, :gossip])
      :ok = Notifier.unlisten(name, :signal)
      :ok = Notifier.notify(name, :signal, %{value: "signal", ident: ident})
      :ok = Notifier.notify(name, :gossip, %{value: "gossip", ident: ident})

      assert_receive {:notification, :gossip, %{"value" => "gossip"}}
      refute_received {:notification, :signal, _}
    end

    @tag :capture_log
    test "listeners survive a notifier crash without resubscribing" do
      name = start_styx!()
      ident = to_ident(name)

      await_joined(name)

      :ok = Notifier.listen(name, :signal)

      notifier_pid = Styx.Registry.whereis(name, Notifier)

      Process.exit(notifier_pid, :kill)

      with_backoff(fn ->
        new_pid = Styx.Registry.whereis(name, Notifier)

        assert is_pid(new_pid) and new_pid != notifier_pid
      end)

      # Give time for the notifier to reconnect before the message arrives.
      with_backoff(fn ->
        Notifier.notify(name, :signal, %{value: "revived", ident: ident})

        assert_receive {:notification, :signal, %{"value" => "revived"}}
      end)
    end

    defp start_styx!, do: start_supervised_styx!(notifier: @notifier, repo: UnboxedRepo)

    defp to_ident(name), do: name |> Styx.config() |> Config.to_ident()

    if @notifier == Styx.Notifiers.PG do
      defp await_joined(_name) do
        case :pg.get_local_members(Styx.Notifiers.PG, "public") do
          [] -> await_joined(nil)
          _ -> :ok
        end
      end
    else
      defp await_joined(_name), do: :ok
    end
  end
end
