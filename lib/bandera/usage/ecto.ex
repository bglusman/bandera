if Code.ensure_loaded?(Ecto.Adapters.SQL) do
  defmodule Bandera.Usage.Ecto do
    @moduledoc """
    Durable DB backend for `Bandera.Usage`.

    Called by `Bandera.Usage` to seed ETS from the DB once the Repo is up, and
    periodically to flush the whole ETS table back, so evaluation history
    survives process restarts and pod recycling.

    The flush is last-writer-wins: across multiple pods the DB row for a flag
    ends up holding whichever pod's value was written most recently. At 30-day
    stale-detection granularity that ~flush-interval skew is irrelevant, and on
    startup every pod re-seeds from the DB and keeps the newer of (DB, in-memory),
    so values only ever move forward in practice.

    The table is separate from the flags table — create it via
    `Bandera.Ecto.Migrations.up_usage/0`.

    Only active when `persistence: [adapter: Bandera.Store.Persistent.Ecto]`
    is configured.  All functions silently no-op on any DB error so ETS-only
    operation continues if the table is absent or the DB is unreachable.
    """

    import Ecto.Query

    alias Bandera.Config
    alias Bandera.Usage.Record

    @doc """
    Loads all rows from the DB usage table into `ets_table`, keeping whichever
    timestamp is newer.  Called once at startup to seed in-memory history.
    """
    @spec load_into_ets(atom) :: :ok
    def load_into_ets(ets_table) do
      rows = repo().all(from(r in {table_name(), Record}))

      for %Record{flag_name: name, last_evaluated_at: db_at} <- rows do
        atom = String.to_atom(name)

        case :ets.lookup(ets_table, atom) do
          [{^atom, mem_at}] ->
            if DateTime.compare(db_at, mem_at) == :gt,
              do: :ets.insert(ets_table, {atom, db_at})

          [] ->
            :ets.insert(ets_table, {atom, db_at})
        end
      end

      :ok
    rescue
      _ -> :ok
    end

    @doc """
    Upserts every `{flag_name, datetime}` pair in `ets_table` into the DB,
    replacing `last_evaluated_at` (last-writer-wins).
    """
    @spec flush_all(atom) :: :ok
    def flush_all(ets_table) do
      rows =
        ets_table
        |> :ets.tab2list()
        |> Enum.map(fn {name, at} ->
          %{flag_name: to_string(name), last_evaluated_at: at}
        end)

      unless rows == [] do
        repo().insert_all(
          table_name(),
          rows,
          on_conflict: {:replace, [:last_evaluated_at]},
          conflict_target: [:flag_name]
        )
      end

      :ok
    rescue
      _ -> :ok
    end

    defp repo, do: Keyword.fetch!(Config.persistence(), :repo)

    defp table_name,
      do: Keyword.get(Config.persistence(), :usage_table_name, "bandera_usage")
  end
end
