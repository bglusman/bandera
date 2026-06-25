defmodule Bandera.UsageTest do
  use ExUnit.Case, async: false
  alias Bandera.Store.Cache
  alias Bandera.Store.Persistent.Memory
  alias Bandera.Usage

  setup do
    start_supervised!(Memory)
    start_supervised!(Cache)
    Application.put_env(:bandera, :cache, enabled: true, ttl: 900)
    Application.put_env(:bandera, :persistence, adapter: Memory)
    Application.put_env(:bandera, :store, Bandera.Store.TwoLevel)
    Bandera.reload_config()
    # Usage self-attaches its telemetry handler in init/1 and detaches on shutdown.
    start_supervised!(Usage)

    on_exit(fn ->
      Application.delete_env(:bandera, :cache)
      Application.delete_env(:bandera, :persistence)
      Application.delete_env(:bandera, :store)
      Bandera.reload_config()
    end)

    :ok
  end

  test "records the last time a flag was evaluated" do
    refute Usage.last_evaluated(:never_checked)

    :telemetry.execute([:bandera, :enabled?], %{system_time: 1}, %{
      flag_name: :checked,
      options: [],
      result: false
    })

    assert %DateTime{} = Usage.last_evaluated(:checked)
  end

  test "re-attaches its telemetry handler after a crash and restart" do
    # Confirm tracking works before the crash.
    :telemetry.execute([:bandera, :enabled?], %{system_time: 1}, %{
      flag_name: :pre_crash,
      options: [],
      result: false
    })

    assert %DateTime{} = Usage.last_evaluated(:pre_crash)

    # Kill the GenServer; start_supervised restarts it, re-running init/1 (which
    # re-attaches the handler against a fresh ETS table).
    pid = Process.whereis(Usage)
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000

    # Wait for the supervisor to bring it back.
    wait_until(fn ->
      case Process.whereis(Usage) do
        nil -> false
        new_pid -> new_pid != pid and Process.alive?(new_pid)
      end
    end)

    # The fresh table starts empty, and a new evaluation is still recorded —
    # proving the handler survived the restart.
    refute Usage.last_evaluated(:pre_crash)

    :telemetry.execute([:bandera, :enabled?], %{system_time: 1}, %{
      flag_name: :post_crash,
      options: [],
      result: false
    })

    assert %DateTime{} = Usage.last_evaluated(:post_crash)
  end

  test "records usage through a real Bandera.enabled?/2 call" do
    {:ok, _} = Bandera.enable(:checked_via_api)
    refute Usage.last_evaluated(:checked_via_api)

    assert Bandera.enabled?(:checked_via_api)
    assert %DateTime{} = Usage.last_evaluated(:checked_via_api)
  end

  test "records usage when a flag is resolved via variant/2" do
    {:ok, _} = Bandera.put_variants(:hero, %{"a" => 1, "b" => 1})
    refute Usage.last_evaluated(:hero)

    _ = Bandera.variant(:hero, for: %{id: 1})
    assert %DateTime{} = Usage.last_evaluated(:hero)
  end

  test "stale_flags returns flags not evaluated within the window" do
    {:ok, _} = Bandera.enable(:fresh)
    {:ok, _} = Bandera.enable(:old)

    # mark :fresh as just-evaluated; leave :old with no/old usage
    :ets.insert(Bandera.Usage, {:fresh, DateTime.utc_now()})
    :ets.insert(Bandera.Usage, {:old, DateTime.add(DateTime.utc_now(), -100, :day)})

    assert :old in Bandera.stale_flags(older_than: 30)
    refute :fresh in Bandera.stale_flags(older_than: 30)
  end

  test "a negative older_than does not mark a freshly-evaluated flag as stale" do
    {:ok, _} = Bandera.enable(:fresh)
    # A clearly-recent evaluation (slightly ahead of now to avoid the now-boundary).
    :ets.insert(Bandera.Usage, {:fresh, DateTime.add(DateTime.utc_now(), 60, :second)})

    # Negative window previously made the cutoff a future date -> everything stale.
    refute :fresh in Bandera.stale_flags(older_than: -100)
  end

  test "stale_flags excludes internal segment definitions" do
    {:ok, _} = Bandera.put_segment(:premium, [{"plan", :eq, "premium"}])

    refute Enum.any?(Bandera.stale_flags(older_than: 30), fn name ->
             String.starts_with?(to_string(name), "bandera_segment:")
           end)
  end

  test "stale_flags reports a flag with no evaluation history as stale" do
    {:ok, _} = Bandera.enable(:unseen)
    assert :unseen in Bandera.stale_flags(older_than: 30)
  end

  test "mix bandera.flags --stale prints stale flag names" do
    import ExUnit.CaptureIO
    {:ok, _} = Bandera.enable(:old)
    :ets.insert(Bandera.Usage, {:old, DateTime.add(DateTime.utc_now(), -100, :day)})

    output =
      capture_io(fn -> Mix.Tasks.Bandera.Flags.run(["--stale", "--older-than", "30"]) end)

    assert output =~ "old"
  end

  # Polls `fun` until it returns true, raising after `timeout` ms. Used to wait on
  # the supervisor's asynchronous restart without a fixed sleep.
  defp wait_until(fun, timeout \\ 1_000, interval \\ 10) do
    cond do
      fun.() ->
        :ok

      timeout <= 0 ->
        flunk("wait_until timed out")

      true ->
        Process.sleep(interval)
        wait_until(fun, timeout - interval, interval)
    end
  end
end
