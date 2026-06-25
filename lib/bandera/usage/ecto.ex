if Code.ensure_loaded?(Ecto.Adapters.SQL) do
  defmodule Bandera.Usage.Ecto do
    @moduledoc """
    Durable DB backend for `Bandera.Usage`.

    Called by `Bandera.Usage` at startup (to seed ETS from the DB) and
    periodically (to flush dirty ETS entries back to the DB), so evaluation
    history survives process restarts and pod recycling.

    Only rows marked dirty since the last flush are written — those timestamps
    are always newer than whatever is in the DB, so multi-pod writes never
    regress a timestamp.

    The table is separate from the flags table — create it via:

        Bandera.Ecto.Migrations.up_usage()

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
    Upserts rows for `dirty_flags` (a `MapSet` of atom flag names) from
    `ets_table` into the DB, replacing `last_evaluated_at`.

    Because only dirty entries are flushed — those written since the last DB
    load or flush — their timestamps are always >= what is in the DB, so
    `{:replace, [:last_evaluated_at]}` is safe across pods.
    """
    @spec flush_dirty(atom, MapSet.t()) :: :ok
    def flush_dirty(_ets_table, dirty) when map_size(dirty) == 0, do: :ok

    def flush_dirty(ets_table, dirty) do
      rows =
        dirty
        |> MapSet.to_list()
        |> Enum.flat_map(fn name ->
          case :ets.lookup(ets_table, name) do
            [{^name, at}] -> [%{flag_name: to_string(name), last_evaluated_at: at}]
            [] -> []
          end
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
