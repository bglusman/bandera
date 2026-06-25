defmodule Bandera.UsageEctoTest do
  use ExUnit.Case, async: false

  alias Bandera.Store.Cache
  alias Bandera.Usage

  setup do
    Bandera.TestRepo.query!("DELETE FROM bandera_usage")

    Application.put_env(:bandera, :cache, enabled: true, ttl: 900)

    Application.put_env(:bandera, :persistence,
      adapter: Bandera.Store.Persistent.Ecto,
      repo: Bandera.TestRepo
    )

    Application.put_env(:bandera, :store, Bandera.Store.TwoLevel)
    Bandera.reload_config()

    start_supervised!(Cache)

    on_exit(fn ->
      Application.delete_env(:bandera, :cache)
      Application.delete_env(:bandera, :persistence)
      Application.delete_env(:bandera, :store)
      Bandera.reload_config()
    end)

    :ok
  end

  test "flush/0 writes dirty ETS entries to the DB" do
    start_supervised!({Usage, flush_interval: 3600})
    :ok = Usage.attach()
    on_exit(fn -> Usage.detach() end)

    Bandera.TestRepo.query!(
      "INSERT INTO bandera_flags (flag_name, gate_type, target, enabled) VALUES ('flush_flag', 'boolean', '_bandera_none', 1)"
    )

    assert Bandera.enabled?(:flush_flag)

    :ok = Usage.flush()

    %{rows: rows} = Bandera.TestRepo.query!("SELECT flag_name FROM bandera_usage")
    assert ["flush_flag"] in rows
  end

  test "history is loaded from DB into ETS on startup" do
    old_time = DateTime.add(DateTime.utc_now(), -45, :day)

    Bandera.TestRepo.query!(
      "INSERT INTO bandera_usage (flag_name, last_evaluated_at) VALUES (?, ?)",
      ["old_flag", DateTime.to_iso8601(old_time)]
    )

    start_supervised!({Usage, flush_interval: 3600})

    assert %DateTime{} = at = Usage.last_evaluated(:old_flag)
    assert DateTime.diff(at, old_time, :second) |> abs() < 2
  end

  test "a flag loaded from DB with old timestamp is reported stale" do
    old_time = DateTime.add(DateTime.utc_now(), -45, :day)

    Bandera.TestRepo.query!(
      "INSERT INTO bandera_usage (flag_name, last_evaluated_at) VALUES (?, ?)",
      ["ancient_flag", DateTime.to_iso8601(old_time)]
    )

    Bandera.TestRepo.query!(
      "INSERT INTO bandera_flags (flag_name, gate_type, target, enabled) VALUES ('ancient_flag', 'boolean', '_bandera_none', 1)"
    )

    start_supervised!({Usage, flush_interval: 3600})

    assert :ancient_flag in Bandera.stale_flags(older_than: 30)
  end

  test "flush does not regress a timestamp already in the DB" do
    now = DateTime.utc_now()
    newer = DateTime.add(now, 10, :second)
    older = DateTime.add(now, -10, :second)

    Bandera.TestRepo.query!(
      "INSERT INTO bandera_usage (flag_name, last_evaluated_at) VALUES (?, ?)",
      ["raced_flag", DateTime.to_iso8601(newer)]
    )

    start_supervised!({Usage, flush_interval: 3600})
    # Simulate ETS having an older timestamp (e.g. loaded from a slower pod)
    :ets.insert(Usage, {:raced_flag, older})

    :ok = Usage.flush()

    %{rows: [[stored]]} =
      Bandera.TestRepo.query!(
        "SELECT last_evaluated_at FROM bandera_usage WHERE flag_name = 'raced_flag'"
      )

    {:ok, stored_dt, _} = DateTime.from_iso8601(stored)
    assert DateTime.compare(stored_dt, older) != :lt
  end
end
