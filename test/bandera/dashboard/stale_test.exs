defmodule Bandera.Dashboard.StaleTest do
  use ExUnit.Case, async: false

  alias Bandera.Dashboard.Stale

  describe "usage_available?/0" do
    test "returns false when Bandera.Usage is not running" do
      refute Stale.usage_available?()
    end

    test "returns true when Bandera.Usage is running" do
      start_supervised!(Bandera.Usage)
      assert Stale.usage_available?()
    end
  end

  describe "stale_set/1" do
    test "returns empty MapSet when Usage is not running" do
      assert Stale.stale_set() == MapSet.new()
    end

    test "returns empty MapSet when all flags have been recently evaluated" do
      setup_store()
      start_supervised!(Bandera.Usage)
      :ets.insert(Bandera.Usage, {:my_flag, DateTime.utc_now()})
      result = Stale.stale_set(older_than: 30)
      refute MapSet.member?(result, :my_flag)
    end

    test "returns flag in MapSet when it was last evaluated beyond the threshold" do
      setup_store()
      {:ok, true} = Bandera.enable(:old_flag)
      start_supervised!(Bandera.Usage)
      old_time = DateTime.add(DateTime.utc_now(), -40 * 86_400, :second)
      :ets.insert(Bandera.Usage, {:old_flag, old_time})
      result = Stale.stale_set(older_than: 30)
      assert MapSet.member?(result, :old_flag)
    end
  end

  describe "age_days/1" do
    test "returns :never when flag has never been evaluated" do
      start_supervised!(Bandera.Usage)
      assert Stale.age_days(:nonexistent_flag) == :never
    end

    test "returns {:ok, days} with correct floor when flag has been evaluated" do
      start_supervised!(Bandera.Usage)
      past = DateTime.add(DateTime.utc_now(), -5 * 86_400 - 3600, :second)
      :ets.insert(Bandera.Usage, {:some_flag, past})
      assert Stale.age_days(:some_flag) == {:ok, 5}
    end

    test "returns :never when Usage is not running" do
      assert Stale.age_days(:any_flag) == :never
    end

    test "clamps future timestamps to 0 days" do
      start_supervised!(Bandera.Usage)
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      :ets.insert(Bandera.Usage, {:future_flag, future})
      assert Stale.age_days(:future_flag) == {:ok, 0}
    end
  end

  defp setup_store do
    start_supervised!(Bandera.Store.Persistent.Memory)
    start_supervised!(Bandera.Store.Cache)
    Application.put_env(:bandera, :cache, enabled: true, ttl: 900)
    Application.put_env(:bandera, :persistence, adapter: Bandera.Store.Persistent.Memory)
    Application.put_env(:bandera, :store, Bandera.Store.TwoLevel)
    Bandera.reload_config()

    on_exit(fn ->
      Application.delete_env(:bandera, :cache)
      Application.delete_env(:bandera, :persistence)
      Application.delete_env(:bandera, :store)
      Bandera.reload_config()
    end)
  end
end
