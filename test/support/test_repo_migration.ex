defmodule Bandera.TestRepo.Migration do
  use Ecto.Migration

  @spec up() :: :ok
  def up do
    Bandera.Ecto.Migrations.up()
    Bandera.Ecto.Migrations.up_usage()
    Bandera.Ecto.Migrations.add_flags_inserted_at()
  end

  @spec down() :: :ok
  def down, do: Bandera.Ecto.Migrations.down()
end
