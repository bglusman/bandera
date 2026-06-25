defmodule Bandera.Usage do
  @moduledoc """
  Optional last-evaluated tracker. Attaches to `[:bandera, :enabled?]` and
  `[:bandera, :variant]` telemetry events and records, in ETS, the last time
  each flag was checked — the signal for `Bandera.stale_flags/1`.

  When the Ecto persistence adapter is configured, evaluation history is also
  persisted to a `bandera_usage` DB table so it survives restarts and pod
  recycling. The DB is seeded into ETS at startup and flushed back every
  `flush_interval` seconds (default 600 / 10 minutes).

  Add to your supervision tree and call `Bandera.Usage.attach/0` once at boot:

      children = [
        ...,
        Bandera.Usage
      ]

  Then in your application `start/2`:

      :ok = Bandera.Usage.attach()

  Create the usage table with `Bandera.Ecto.Migrations.up_usage/0` from a
  migration before enabling DB persistence.
  """
  use GenServer

  alias Bandera.Config

  @table __MODULE__
  @handler {__MODULE__, :usage}
  @events [[:bandera, :enabled?], [:bandera, :variant]]
  @default_flush_interval 600

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc "Starts the Usage tracker. Add to your supervision tree."
  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, opts, Keyword.put_new(opts, :name, __MODULE__))

  @doc "Registers the telemetry handler. Call once after the supervisor starts."
  @spec attach() :: :ok | {:error, :already_exists}
  def attach do
    :telemetry.attach_many(@handler, @events, &__MODULE__.handle_event/4, nil)
  end

  @doc "Unregisters the telemetry handler."
  @spec detach() :: :ok | {:error, :not_found}
  def detach, do: :telemetry.detach(@handler)

  @doc "Returns the last UTC `DateTime` `flag_name` was evaluated, or `nil` if never seen."
  @spec last_evaluated(atom) :: DateTime.t() | nil
  def last_evaluated(flag_name) do
    case :ets.lookup(@table, flag_name) do
      [{^flag_name, at}] -> at
      [] -> nil
    end
  end

  @doc "Immediately flushes dirty entries to the DB. Useful in tests and clean shutdowns."
  @spec flush() :: :ok
  def flush, do: GenServer.call(__MODULE__, :flush)

  # ── Telemetry handler (called from any process) ────────────────────────────

  @doc false
  @spec handle_event(list, map, map, term) :: :ok
  def handle_event([:bandera, _event], _measurements, %{flag_name: flag_name}, _config) do
    # Never raise: :telemetry would detach us on error, silently stopping tracking.
    :ets.insert(@table, {flag_name, DateTime.utc_now()})
    notify_dirty(flag_name)
    :ok
  rescue
    _ -> :ok
  end

  # ── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])

    interval = flush_interval(opts)
    state = %{dirty: MapSet.new(), flush_interval: interval}

    # Seed ETS from DB (if Ecto adapter is configured), then schedule first flush.
    maybe_load_from_db()
    schedule_flush(interval)

    {:ok, state}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    maybe_flush_to_db(state.dirty)
    {:reply, :ok, %{state | dirty: MapSet.new()}}
  end

  @impl true
  def handle_cast({:dirty, flag_name}, state) do
    {:noreply, %{state | dirty: MapSet.put(state.dirty, flag_name)}}
  end

  @impl true
  def handle_info(:flush, state) do
    maybe_flush_to_db(state.dirty)
    schedule_flush(state.flush_interval)
    {:noreply, %{state | dirty: MapSet.new()}}
  end

  # ── Private helpers ─────────────────────────────────────────────────────────

  defp notify_dirty(flag_name) do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:dirty, flag_name})
    end
  end

  defp schedule_flush(interval),
    do: Process.send_after(self(), :flush, interval * 1_000)

  defp ecto_adapter? do
    Config.persistence_adapter() == Bandera.Store.Persistent.Ecto
  rescue
    _ -> false
  end

  defp maybe_load_from_db do
    if ecto_adapter?() and Code.ensure_loaded?(Bandera.Usage.Ecto) do
      Bandera.Usage.Ecto.load_into_ets(@table)
    end
  end

  defp maybe_flush_to_db(dirty) do
    if ecto_adapter?() and Code.ensure_loaded?(Bandera.Usage.Ecto) do
      Bandera.Usage.Ecto.flush_dirty(@table, dirty)
    end
  end

  defp flush_interval(opts) do
    Keyword.get_lazy(opts, :flush_interval, fn ->
      :bandera
      |> Application.get_env(:usage, [])
      |> Keyword.get(:flush_interval, @default_flush_interval)
    end)
  end
end
