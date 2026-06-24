if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Bandera.Dashboard.Stale do
    @moduledoc """
    Pure helper for stale flag detection in the dashboard.
    Requires `Bandera.Usage` to be running and attached for meaningful results.
    """

    @default_older_than 30

    @doc "Returns true if the Bandera.Usage GenServer is running."
    @spec usage_available?() :: boolean
    def usage_available?, do: not is_nil(Process.whereis(Bandera.Usage))

    @doc """
    Returns a MapSet of atom flag names considered stale.
    Passes `older_than` (days, default 30) to `Bandera.stale_flags/1`.
    Returns an empty MapSet if Usage is not running.
    """
    @spec stale_set(keyword) :: MapSet.t(atom)
    def stale_set(opts \\ []) do
      if usage_available?() do
        days = Keyword.get(opts, :older_than, config_older_than())
        Bandera.stale_flags(older_than: days) |> MapSet.new()
      else
        MapSet.new()
      end
    end

    @doc """
    Returns `{:ok, days}` where days is how long ago the flag was last evaluated,
    or `:never` if it has never been evaluated or Usage is not running.
    """
    @spec age_days(atom) :: {:ok, non_neg_integer} | :never
    def age_days(flag_name) do
      if usage_available?() do
        case Bandera.Usage.last_evaluated(flag_name) do
          nil -> :never
          at -> {:ok, max(0, floor(DateTime.diff(DateTime.utc_now(), at, :second) / 86_400))}
        end
      else
        :never
      end
    end

    defp config_older_than do
      :bandera
      |> Application.get_env(:dashboard, [])
      |> Keyword.get(:stale_older_than, @default_older_than)
    end
  end
end
