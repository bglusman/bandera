if Code.ensure_loaded?(Ecto.Adapters.SQL) do
  defmodule Bandera.Store.Persistent.Ecto do
    @moduledoc """
    SQL persistence adapter. The repo and table name are read from
    `Bandera.Config` at RUNTIME and queries are schemaless, so nothing about the
    table is fixed at compile time.

    Configure:

        config :bandera,
          persistence: [
            adapter: Bandera.Store.Persistent.Ecto,
            repo: MyApp.Repo,
            ecto_table_name: "bandera_flags"
          ]

    Run `Bandera.Ecto.Migrations.up/0` from a migration to create the table.
    """

    @behaviour Bandera.Store.Persistent

    import Ecto.Query

    alias Bandera.Config
    alias Bandera.Flag
    alias Bandera.Gate
    alias Bandera.Store.Persistent.Ecto.Serializer

    @impl Bandera.Store.Persistent
    def get(flag_name) do
      name = to_string(flag_name)

      rows =
        from(t in table(),
          where: t.flag_name == ^name,
          select: %{
            gate_type: t.gate_type,
            target: t.target,
            enabled: type(t.enabled, :boolean)
          }
        )
        |> repo().all()

      {:ok, Serializer.deserialize_flag(flag_name, rows)}
    end

    @impl Bandera.Store.Persistent
    def put(flag_name, %Gate{type: type} = gate)
        when type in [:percentage_of_time, :percentage_of_actors] do
      name = to_string(flag_name)
      row = dump_row(Serializer.to_row(flag_name, gate))

      repo().transaction(fn ->
        from(t in table(), where: t.flag_name == ^name and t.gate_type == "percentage")
        |> repo().delete_all()

        repo().insert_all(table(), [row])
      end)

      get(flag_name)
    end

    @impl Bandera.Store.Persistent
    def put(flag_name, %Gate{} = gate) do
      row = dump_row(Serializer.to_row(flag_name, gate))

      repo().insert_all(table(), [row],
        on_conflict: [set: [enabled: dump_boolean(gate.enabled)]],
        conflict_target: [:flag_name, :gate_type, :target]
      )

      get(flag_name)
    end

    @impl Bandera.Store.Persistent
    def delete(flag_name, %Gate{type: type})
        when type in [:percentage_of_time, :percentage_of_actors] do
      name = to_string(flag_name)

      from(t in table(), where: t.flag_name == ^name and t.gate_type == "percentage")
      |> repo().delete_all()

      get(flag_name)
    end

    @impl Bandera.Store.Persistent
    def delete(flag_name, %Gate{} = gate) do
      name = to_string(flag_name)
      gate_type = to_string(gate.type)
      target = Serializer.serialize_target(gate.for)

      from(t in table(),
        where: t.flag_name == ^name and t.gate_type == ^gate_type and t.target == ^target
      )
      |> repo().delete_all()

      get(flag_name)
    end

    @impl Bandera.Store.Persistent
    def delete(flag_name) do
      name = to_string(flag_name)

      from(t in table(), where: t.flag_name == ^name)
      |> repo().delete_all()

      {:ok, Flag.new(flag_name, [])}
    end

    @impl Bandera.Store.Persistent
    def all_flags do
      flags =
        from(t in table(),
          select: %{
            flag_name: t.flag_name,
            gate_type: t.gate_type,
            target: t.target,
            enabled: type(t.enabled, :boolean)
          }
        )
        |> repo().all()
        |> Enum.group_by(& &1.flag_name)
        |> Enum.map(fn {name, rows} -> Serializer.deserialize_flag(name, rows) end)

      {:ok, flags}
    end

    @impl Bandera.Store.Persistent
    def all_flag_names do
      names =
        from(t in table(), select: t.flag_name, distinct: true)
        |> repo().all()
        |> Enum.map(&String.to_atom/1)

      {:ok, names}
    end

    defp repo, do: Keyword.fetch!(Config.persistence(), :repo)
    defp table, do: Config.ecto_table_name()

    # Schemaless `insert_all` carries no field types, so the adapter cannot rely on
    # the Ecto type to dump booleans for the underlying database. We dump the only
    # typed column (`enabled`) here and cast it back with `type(t.enabled, :boolean)`
    # on read, keeping a portable 1/0 representation on disk.
    defp dump_row(%{enabled: enabled} = row), do: %{row | enabled: dump_boolean(enabled)}

    defp dump_boolean(true), do: 1
    defp dump_boolean(false), do: 0
  end
end
