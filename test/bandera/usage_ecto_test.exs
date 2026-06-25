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

  test "flush/0 writes ETS entries to the DB" do
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

  test "seeds from the DB on a later flush tick if the Repo was not ready at init" do
    # Simulate umbrella boot order: Usage starts, but no usage rows exist yet at
    # init. A row appears (as if written by another pod), and the next flush tick
    # must seed it into ETS — proving the load is retried, not one-shot at init.
    start_supervised!({Usage, flush_interval: 3600})
    refute Usage.last_evaluated(:late_seed)

    # Force loaded? back to false to model "Repo wasn't alive at init".
    :sys.replace_state(Usage, fn state -> %{state | loaded?: false} end)

    old_time = DateTime.add(DateTime.utc_now(), -45, :day)

    Bandera.TestRepo.query!(
      "INSERT INTO bandera_usage (flag_name, last_evaluated_at) VALUES (?, ?)",
      ["late_seed", DateTime.to_iso8601(old_time)]
    )

    # A flush tick re-attempts the seed.
    :ok = Usage.flush()

    assert %DateTime{} = Usage.last_evaluated(:late_seed)
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

  test "load keeps the DB value when it is newer than what is in ETS" do
    now = DateTime.utc_now()
    db_newer = DateTime.add(now, 10, :second)
    mem_older = DateTime.add(now, -10, :second)

    Bandera.TestRepo.query!(
      "INSERT INTO bandera_usage (flag_name, last_evaluated_at) VALUES (?, ?)",
      ["db_wins", DateTime.to_iso8601(db_newer)]
    )

    start_supervised!({Usage, flush_interval: 3600})
    :ets.insert(Usage, {:db_wins, mem_older})

    Bandera.Usage.Ecto.load_into_ets(Usage)

    assert DateTime.compare(Usage.last_evaluated(:db_wins), mem_older) == :gt
  end

  test "load keeps the in-memory value when it is newer than the DB" do
    now = DateTime.utc_now()
    db_older = DateTime.add(now, -10, :second)
    mem_newer = DateTime.add(now, 10, :second)

    Bandera.TestRepo.query!(
      "INSERT INTO bandera_usage (flag_name, last_evaluated_at) VALUES (?, ?)",
      ["mem_wins", DateTime.to_iso8601(db_older)]
    )

    start_supervised!({Usage, flush_interval: 3600})
    :ets.insert(Usage, {:mem_wins, mem_newer})

    Bandera.Usage.Ecto.load_into_ets(Usage)

    assert DateTime.compare(Usage.last_evaluated(:mem_wins), db_older) == :gt
  end
end
