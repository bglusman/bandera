if Code.ensure_loaded?(Ecto.Migration) do
  defmodule Bandera.Ecto.Migrations do
    @moduledoc """
    Helpers for creating the Bandera flags table. Call from your own migration:

        defmodule MyApp.Repo.Migrations.CreateBanderaFlags do
          use Ecto.Migration
          def up, do: Bandera.Ecto.Migrations.up()
          def down, do: Bandera.Ecto.Migrations.down()
        end

    The table name is read at runtime from `config :bandera, persistence: [ecto_table_name: ...]`
    (default `"bandera_flags"`), so it is never fixed at compile time.
    """

    import Ecto.Migration

    @doc """
    Creates the flags table and its unique index (idempotently).

    Call from the `up/0` of your own migration. The table name is read at runtime
    from `Bandera.Config.ecto_table_name/0`.
    """
    @spec up() :: :ok
    def up do
      table_name = Bandera.Config.ecto_table_name()

      create_if_not_exists table(table_name) do
        add(:flag_name, :string, null: false)
        add(:gate_type, :string, null: false)
        add(:target, :string, null: false)
        add(:enabled, :boolean, null: false)
        add(:value, :string)
      end

      create_if_not_exists(
        unique_index(table_name, [:flag_name, :gate_type, :target],
          name: :"#{table_name}_flag_name_gate_target_idx"
        )
      )

      :ok
    end

    @doc """
    Add the schema-v2 `value` column to an existing flags table.

    Call once from the `up/0` of a versioned migration in an existing install:

        defmodule MyApp.Repo.Migrations.UpgradeBanderaV2 do
          use Ecto.Migration
          def up, do: Bandera.Ecto.Migrations.upgrade_v2()
        end

    Uses a plain `add/2` (not `add_if_not_exists/2`) so it works on adapters such as
    SQLite3 that reject conditional column additions; migration versioning ensures it
    runs only once.
    """
    @spec upgrade_v2() :: :ok
    def upgrade_v2 do
      alter table(Bandera.Config.ecto_table_name()) do
        add(:value, :string)
      end

      :ok
    end

    @doc """
    Fixes boolean gate rows left by a FunWithFlags-to-Bandera migration.

    FunWithFlags stored boolean gates with a legacy `target` value; Bandera uses
    `"_bandera_none"`. Because the Ecto adapter's upsert conflict target is
    `(flag_name, gate_type, target)`, toggling a flag via Bandera after migration
    inserts a second boolean row rather than updating the legacy one. This leaves
    two rows with contradictory `enabled` values, causing the dashboard toggle and
    summary to disagree and making the toggle appear broken.

    Run once from a migration after switching to Bandera:

        defmodule MyApp.Repo.Migrations.FixFunWithFlagsBooleanGates do
          use Ecto.Migration
          def up, do: Bandera.Ecto.Migrations.fix_fun_with_flags_boolean_gates()
          def down, do: :ok
        end

    Safe to run on a database that has already been fully migrated — it will find
    nothing to change. Not reversible (`down` should be a no-op).
    """
    @spec fix_fun_with_flags_boolean_gates() :: :ok
    def fix_fun_with_flags_boolean_gates do
      table = Bandera.Config.ecto_table_name()
      # `table` is developer-controlled config; '_bandera_none' is a fixed sentinel.

      # When both a legacy row and a Bandera row exist for the same flag, delete
      # the legacy row. The Bandera row reflects the most recent intent.
      execute("""
      DELETE FROM #{table}
      WHERE gate_type = 'boolean'
        AND target != '_bandera_none'
        AND flag_name IN (
          SELECT flag_name FROM #{table}
          WHERE gate_type = 'boolean' AND target = '_bandera_none'
        )
      """)

      # Rename any remaining legacy rows so future Bandera writes upsert correctly.
      execute("""
      UPDATE #{table}
      SET target = '_bandera_none'
      WHERE gate_type = 'boolean'
        AND target != '_bandera_none'
      """)

      :ok
    end

    @doc """
    Creates the usage table for durable stale-flag detection.

    Call from the `up/0` of your own migration:

        defmodule MyApp.Repo.Migrations.CreateBanderaUsage do
          use Ecto.Migration
          def up, do: Bandera.Ecto.Migrations.up_usage()
          def down, do: Bandera.Ecto.Migrations.down_usage()
        end

    The table stores one row per flag — the timestamp it was last evaluated
    anywhere in the fleet. `Bandera.Usage` flushes to this table periodically
    (default every 10 minutes) and seeds ETS from it at startup.
    """
    @spec up_usage() :: :ok
    def up_usage do
      table_name = usage_table_name()

      create_if_not_exists table(table_name, primary_key: false) do
        add(:flag_name, :string, primary_key: true, null: false)
        add(:last_evaluated_at, :utc_datetime_usec, null: false)
      end

      :ok
    end

    @doc "Drops the usage table."
    @spec down_usage() :: :ok
    def down_usage do
      drop(table(usage_table_name()))
      :ok
    end

    @doc """
    Adds an `inserted_at` column to the flags table so you can see when each
    flag/gate row was first created.

    Call from a versioned migration in an existing install:

        defmodule MyApp.Repo.Migrations.AddBanderaFlagsInsertedAt do
          use Ecto.Migration
          def up, do: Bandera.Ecto.Migrations.add_flags_inserted_at()
          def down, do: Bandera.Ecto.Migrations.remove_flags_inserted_at()
        end
    """
    @spec add_flags_inserted_at() :: :ok
    def add_flags_inserted_at do
      alter table(Bandera.Config.ecto_table_name()) do
        add(:inserted_at, :utc_datetime_usec)
      end

      :ok
    end

    @doc "Removes the `inserted_at` column from the flags table."
    @spec remove_flags_inserted_at() :: :ok
    def remove_flags_inserted_at do
      alter table(Bandera.Config.ecto_table_name()) do
        remove(:inserted_at, :utc_datetime_usec)
      end

      :ok
    end

    @doc "Drops the flags table. Call from the `down/0` of your own migration."
    @spec down() :: :ok
    def down do
      drop(table(Bandera.Config.ecto_table_name()))
      :ok
    end

    defp usage_table_name do
      :bandera
      |> Application.get_env(:persistence, [])
      |> Keyword.get(:usage_table_name, "bandera_usage")
    end
  end
end
