if Code.ensure_loaded?(Ecto.Schema) do
  defmodule Bandera.Usage.Record do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:flag_name, :string, autogenerate: false}
    schema "bandera_usage" do
      field(:last_evaluated_at, :utc_datetime_usec)
    end
  end
end
