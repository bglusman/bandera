defmodule Bandera.TestRepo.Migration do
  use Ecto.Migration

  def up, do: Bandera.Ecto.Migrations.up()
  def down, do: Bandera.Ecto.Migrations.down()
end
