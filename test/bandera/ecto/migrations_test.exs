defmodule Bandera.Ecto.MigrationsTest do
  use ExUnit.Case, async: false

  defmodule UpgradeV2Migration do
    use Ecto.Migration

    @spec up() :: :ok
    def up, do: Bandera.Ecto.Migrations.upgrade_v2()
  end

  setup do
    Bandera.TestRepo.query!("DELETE FROM bandera_flags")
    :ok
  end

  defp column_names(table) do
    Bandera.TestRepo
    |> Ecto.Adapters.SQL.query!("PRAGMA table_info(#{table})")
    |> Map.fetch!(:rows)
    |> Enum.map(fn row -> Enum.at(row, 1) end)
  end

  test "the migration created the flags table with the expected columns" do
    %{rows: rows} =
      Bandera.TestRepo.query!("SELECT flag_name, gate_type, target, enabled FROM bandera_flags")

    assert rows == []
  end

  test "the unique index exists" do
    %{rows: rows} =
      Bandera.TestRepo.query!(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='bandera_flags_flag_name_gate_target_idx'"
      )

    assert rows == [["bandera_flags_flag_name_gate_target_idx"]]
  end

  test "the flags table has a nullable value column (schema v2)" do
    assert "value" in column_names("bandera_flags")
  end

  test "upgrade_v2/0 adds the value column to an existing v1 table" do
    table = "bandera_flags_v1_upgrade_test"

    Bandera.TestRepo.query!("""
    CREATE TABLE #{table} (
      id INTEGER PRIMARY KEY,
      flag_name TEXT NOT NULL,
      gate_type TEXT NOT NULL,
      target TEXT NOT NULL,
      enabled BOOLEAN NOT NULL
    )
    """)

    previous = Application.get_env(:bandera, :persistence, [])
    Application.put_env(:bandera, :persistence, Keyword.put(previous, :ecto_table_name, table))
    Bandera.reload_config()

    on_exit(fn ->
      Application.put_env(:bandera, :persistence, previous)
      Bandera.reload_config()
      Bandera.TestRepo.query!("DROP TABLE IF EXISTS #{table}")
    end)

    refute "value" in column_names(table)

    Ecto.Migrator.run(
      Bandera.TestRepo,
      [{20_260_201_000_000, UpgradeV2Migration}],
      :up,
      all: true,
      log: false
    )

    assert "value" in column_names(table)
  end
end
