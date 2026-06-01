defmodule Mix.Tasks.Bandera.Gen.FixFunWithFlagsMigrationTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @task Mix.Tasks.Bandera.Gen.FixFunWithFlagsMigration

  setup do
    path =
      Path.join(
        System.tmp_dir!(),
        "bandera_test_migrations_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(path)
    on_exit(fn -> File.rm_rf!(path) end)
    {:ok, path: path}
  end

  test "generates a migration file in the given path", %{path: path} do
    capture_io(fn -> @task.run(["--path", path]) end)

    files = File.ls!(path)
    assert length(files) == 1
    assert hd(files) =~ ~r/^\d{14}_fix_fun_with_flags_boolean_gates\.exs$/
  end

  test "generated file contains the correct module and helper call", %{path: path} do
    capture_io(fn -> @task.run(["--path", path]) end)

    content = path |> File.ls!() |> hd() |> then(&File.read!(Path.join(path, &1)))

    assert content =~ "use Ecto.Migration"
    assert content =~ "Bandera.Ecto.Migrations.fix_fun_with_flags_boolean_gates()"
    assert content =~ "def up"
    assert content =~ "def down, do: :ok"
  end

  test "prints the path of the generated file", %{path: path} do
    output = capture_io(fn -> @task.run(["--path", path]) end)

    assert output =~ path
    assert output =~ "_fix_fun_with_flags_boolean_gates.exs"
  end

  test "defaults to priv/repo/migrations when no --path given" do
    default_path = Path.join(File.cwd!(), "priv/repo/migrations")

    on_exit(fn ->
      File.ls!(default_path)
      |> Enum.filter(&(&1 =~ "fix_fun_with_flags"))
      |> Enum.each(&File.rm!(Path.join(default_path, &1)))
    end)

    output = capture_io(fn -> @task.run([]) end)

    assert output =~ default_path
    assert output =~ "_fix_fun_with_flags_boolean_gates.exs"
  end
end
