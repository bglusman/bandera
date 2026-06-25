defmodule Bandera.Usage do
  @moduledoc """
  Optional last-evaluated tracker. Attaches to `[:bandera, :enabled?]` and
  `[:bandera, :variant]` telemetry events and records, in ETS, the last time
  each flag was checked — the signal for `Bandera.stale_flags/1`.

  When the Ecto persistence adapter is configured, evaluation history is also
  persisted to a `bandera_usage` DB table so it survives restarts and pod
  recycling. The DB is seeded into ETS once the Repo is available, and the whole
  ETS table is flushed back every `flush_interval` seconds (default 600 / 10
  minutes). At 30-day stale granularity the flush cadence is irrelevant, so the
  flush is a simple last-writer-wins upsert — no per-write bookkeeping on the
  hot path.

  Just add it to your supervision tree — it attaches its own telemetry handler in
  `init/1` and detaches on shutdown, so the handler's lifecycle follows the
  process (a crash-and-restart re-attaches against a fresh ETS table):

      children = [
        ...,
        Bandera.Usage
      ]

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

  @doc """
  Registers the telemetry handler.

  Called automatically from the GenServer's `init/1`; you do not need to call it
  yourself. Exposed mainly for tests.
  """
  @spec attach() :: :ok | {:error, :already_exists}
  def attach do
    :telemetry.attach_many(@handler, @events, &__MODULE__.handle_event/4, nil)
  end

  @doc "Unregisters the telemetry handler. Called automatically on shutdown."
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

  @doc "Immediately flushes ETS to the DB. Useful in tests and clean shutdowns."
  @spec flush() :: :ok
  def flush, do: GenServer.call(__MODULE__, :flush)

  # ── Telemetry handler (called from any process) ────────────────────────────

  @doc false
  @spec handle_event(list, map, map, term) :: :ok
  def handle_event([:bandera, _event], _measurements, %{flag_name: flag_name}, _config) do
    # Hot path: a single ETS write, nothing else. Never raise — :telemetry would
    # detach us on error, silently stopping tracking.
    :ets.insert(@table, {flag_name, DateTime.utc_now()})
    :ok
  rescue
    _ -> :ok
  end

  # ── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    # Trap exits so terminate/2 runs on supervisor shutdown — a final flush plus
    # detach, keeping the handler's lifecycle tied to this process.
    Process.flag(:trap_exit, true)

    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])

    # Attach the telemetry handler here (not from the host application) so that a
    # crash-and-restart re-registers it against the fresh ETS table this init
    # creates. attach/0 is idempotent: a stale handler from a prior incarnation is
    # detached first so the re-attach always succeeds.
    detach()
    attach()

    interval = flush_interval(opts)
    # `loaded?` tracks whether we have seeded ETS from the DB yet. We may start
    # before the host Repo (umbrella boot order), so seeding is retried on each
    # flush tick until it succeeds rather than assumed to work at init.
    state = %{flush_interval: interval, loaded?: false}

    state = maybe_load_from_db(state)
    schedule_flush(interval)

    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    # Best-effort: detach the handler (its ETS table is about to vanish) and flush
    # what we have so a clean shutdown doesn't lose up to a full interval of data.
    detach()
    flush_to_db()
    :ok
  rescue
    _ -> :ok
  end

  @impl true
  def handle_call(:flush, _from, state) do
    state = maybe_load_from_db(state)
    flush_to_db()
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:flush, state) do
    # Keep trying to seed from the DB until it sticks (Repo may boot after us).
    state = maybe_load_from_db(state)
    flush_to_db()
    schedule_flush(state.flush_interval)
    {:noreply, state}
  end

  # ── Private helpers ─────────────────────────────────────────────────────────

  defp schedule_flush(interval),
    do: Process.send_after(self(), :flush, interval * 1_000)

  defp db_enabled? do
    Config.persistence_adapter() == Bandera.Store.Persistent.Ecto and
      Code.ensure_loaded?(Bandera.Usage.Ecto) and repo_alive?()
  rescue
    _ -> false
  end

  defp repo_alive? do
    case Keyword.get(Config.persistence(), :repo) do
      nil -> false
      repo -> is_pid(GenServer.whereis(repo))
    end
  rescue
    _ -> false
  end

  # Seed ETS from the DB exactly once, once the Repo is up. No-ops if already
  # loaded or if the DB isn't available yet (retried on the next flush tick).
  defp maybe_load_from_db(%{loaded?: true} = state), do: state

  defp maybe_load_from_db(state) do
    if db_enabled?() do
      Bandera.Usage.Ecto.load_into_ets(@table)
      %{state | loaded?: true}
    else
      state
    end
  end

  defp flush_to_db do
    if db_enabled?(), do: Bandera.Usage.Ecto.flush_all(@table)
  end

  defp flush_interval(opts) do
    Keyword.get_lazy(opts, :flush_interval, fn ->
      :bandera
      |> Application.get_env(:usage, [])
      |> Keyword.get(:flush_interval, @default_flush_interval)
    end)
  end
end
