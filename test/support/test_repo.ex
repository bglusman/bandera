defmodule Bandera.TestRepo do
  use Ecto.Repo, otp_app: :bandera, adapter: Ecto.Adapters.SQLite3
end
