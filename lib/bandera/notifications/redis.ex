if Code.ensure_loaded?(Redix.PubSub) do
  defmodule Bandera.Notifications.Redis do
    @moduledoc """
    Redis PubSub cache-busting notifier (via Redix). Subscribes to a channel and,
    on a flag change published by ANOTHER node, busts the local cache entry for
    that flag. Self-published changes are ignored. Connection options are read at
    runtime from `config :bandera, cache_bust_notifications: [redis: <Redix opts>]`.
    """

    use GenServer
    @behaviour Bandera.Notifications

    alias Bandera.Config
    alias Bandera.Store.Cache

    @channel "bandera:changes"

    @spec start_link(keyword) :: GenServer.on_start()
    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    @impl Bandera.Notifications
    def publish_change(flag_name) do
      GenServer.call(__MODULE__, {:publish_change, flag_name})
    end

    @impl Bandera.Notifications
    def unique_id do
      GenServer.call(__MODULE__, :unique_id)
    end

    @impl GenServer
    def init(opts) do
      redis_opts = Keyword.merge(redis_config(), opts)
      {:ok, pub} = Redix.start_link(redis_opts)
      {:ok, sub} = Redix.PubSub.start_link(redis_opts)
      {:ok, _ref} = Redix.PubSub.subscribe(sub, @channel, self())
      {:ok, %{unique_id: Config.build_unique_id(), pub: pub, sub: sub}}
    end

    @impl GenServer
    def handle_call({:publish_change, flag_name}, _from, %{pub: pub, unique_id: id} = state) do
      result = Redix.command(pub, ["PUBLISH", @channel, "#{id}:#{flag_name}"])
      {:reply, normalize(result), state}
    end

    def handle_call(:unique_id, _from, %{unique_id: id} = state) do
      {:reply, id, state}
    end

    @impl GenServer
    def handle_info(
          {:redix_pubsub, _pid, _ref, :message, %{channel: @channel, payload: payload}},
          state
        ) do
      handle_payload(payload, state.unique_id)
      {:noreply, state}
    end

    def handle_info({:redix_pubsub, _pid, _ref, _kind, _meta}, state) do
      {:noreply, state}
    end

    defp handle_payload(payload, own_id) do
      case String.split(payload, ":", parts: 2) do
        [^own_id, _flag] -> :ok
        [_other_id, flag] -> Cache.bust(String.to_atom(flag))
        _ -> :ok
      end
    end

    defp normalize({:ok, _}), do: :ok
    defp normalize({:error, reason}), do: {:error, reason}

    defp redis_config, do: Keyword.get(Config.notifications(), :redis, [])
  end
end
