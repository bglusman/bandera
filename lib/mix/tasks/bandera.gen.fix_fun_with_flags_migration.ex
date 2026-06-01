defmodule Mix.Tasks.Bandera.Gen.FixFunWithFlagsMigration do
  @moduledoc """
  Generates an Ecto migration that fixes duplicate boolean gate rows left by a
  FunWithFlags-to-Bandera migration.

  ## Usage

      mix bandera.gen.fix_fun_with_flags_migration [--path PATH]

  ## Options

    * `--path` — directory to write the migration file into.
      Defaults to `priv/repo/migrations`.

  ## What it generates

      defmodule MyApp.Repo.Migrations.FixFunWithFlagsBooleanGates do
        use Ecto.Migration
        def up, do: Bandera.Ecto.Migrations.fix_fun_with_flags_boolean_gates()
        def down, do: :ok
      end

  Run `mix ecto.migrate` after generating the file.
  """
  @shortdoc "Generate a migration to fix FunWithFlags boolean gate rows"
  use Mix.Task

  @default_path "priv/repo/migrations"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [path: :string])
    path = Keyword.get(opts, :path, @default_path)
    abs_path = Path.expand(path)

    File.mkdir_p!(abs_path)

    filename = "#{timestamp()}_fix_fun_with_flags_boolean_gates.exs"
    filepath = Path.join(abs_path, filename)

    File.write!(filepath, migration_content())
    Mix.shell().info("Generated migration: #{filepath}")
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  defp migration_content do
    """
    defmodule MyApp.Repo.Migrations.FixFunWithFlagsBooleanGates do
      use Ecto.Migration

      def up, do: Bandera.Ecto.Migrations.fix_fun_with_flags_boolean_gates()
      def down, do: :ok
    end
    """
  end
end
