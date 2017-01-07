defmodule TorrentDownloader.Tracker do
  @moduledoc """
  Process representing the state of a tracker for a specific torrent.
  """
  @behaviour :gen_statem
  alias TorrentDownloader.{NameRegistry, Torrent, TrackerRegistry}
  alias TrackerClient.Peer

  defmodule Data do
    @moduledoc false
    alias TrackerClient.{HTTP, UDP}

    defstruct [
      url: nil,
      request_mod: nil,
      info_hash: nil,
      peer_id: nil,
      port: 0,
      numwant: nil,
      trackerid: nil,
      seeders: 0,
      leechers: 0,
      peers: [],
      interval: 0,
    ]

    def new(<<"http", _ :: binary>> = url, info_hash, params) do
      new(url, HTTP, info_hash, params)
    end
    def new(<<"udp", _ :: binary>> = url, info_hash, params) do
      new(url, UDP, info_hash, params)
    end

    defp new(url, request_mod, info_hash, params) do
      struct(__MODULE__, [url: url, request_mod: request_mod, info_hash: info_hash] ++ params)
    end

    def update(tracker, announcement) do
      params = [
        seeders: announcement.seeders,
        leechers: announcement.leechers,
        peers: announcement.peers,
        trackerid: announcement.trackerid,
        interval: announcement.interval,
      ]
      struct(tracker, params)
    end
  end

  @doc """
  Starts a new tracker state machine.
  """
  @spec start_link(Torrent.info_hash, String.t, Keyword.t) :: :gen_statem.start_ret
  def start_link(info_hash, url, params) do
    :gen_statem.start_link(NameRegistry.tracker_via(info_hash, url), __MODULE__, [info_hash, url, params], [])
  end

  @doc """
  The tracker process starts making regular announcements.
  """
  @spec start_announcing(pid) :: :ok
  def start_announcing(pid) do
    :gen_statem.cast(pid, :start_announcing)
  end

  @doc """
  The tracker process stops making regular announcements.
  """
  @spec stop_announcing(pid) :: :ok
  def stop_announcing(pid) do
    :gen_statem.cast(pid, :stop_announcing)
  end

  @doc """
  Gets the list of peers from a tracker.
  """
  @spec peers(pid) :: [Peer.t]
  def peers(pid) do
    :gen_statem.call(pid, :peers)
  end

  @doc false
  def init([info_hash, url, params]) do
    {:ok, _pid} = TrackerRegistry.register(info_hash, url)
    data = Data.new(url, info_hash, params)
    {:ok, :not_started, data}
  end

  def handle_event({:call, from}, :peers, _state, data) do
    {:keep_state_and_data, {:reply, from, data.peers}}
  end
  def handle_event(:cast, :start_announcing, :not_started, data) do
    case announce(data, :started) do
      {:ok, announcement} ->
        {:next_state, :working, Data.update(data, announcement)}
      {:error, reason} ->
        {:next_state, {:not_working, reason}, data}
    end
  end
  def handle_event(:cast, :start_announcing, _, _data) do
    :keep_state_and_data
  end
  def handle_event(:cast, :stop_announcing, :not_started, _data) do
    :keep_state_and_data
  end
  def handle_event(:cast, :stop_announcing, _state, data) do
    {:next_state, :not_started, data}
  end
  def handle_event(:info, :announce, :working, data) do
    case announce(data) do
      {:ok, announcement} ->
        {:keep_state, Data.update(data, announcement)}
      {:error, reason} ->
        {:next_state, {:not_working, reason}, data}
    end
  end
  def handle_event(:info, :announce, _state, _data) do
    :keep_state_and_data
  end

  defp announce(data, event \\ nil) do
    params = announce_params(data, event)
    case data.request_mod.announce(data.url, params) do
      {:ok, announcement} ->
        Process.send_after(self(), :announce, announcement.interval * 1_000)
        {:ok, announcement}
      err ->
        err
    end
  end

  defp announce_params(data, event) do
    data.info_hash
    |> Torrent.stats()
    |> Keyword.merge([
      info_hash: data.info_hash,
      peer_id: data.peer_id,
      port: data.port,
      uploaded: 0,
      downloaded: 0,
      left: 0,
      compact: 1
    ])
    |> maybe_add(:event, event)
    |> maybe_add(:numwant, data.numwant)
    |> maybe_add(:numwant, data.trackerid)
  end

  defp maybe_add(params, _key, nil), do: params
  defp maybe_add(params, key, value), do: Keyword.put(params, key, value)

  @doc false
  def terminate(_reason, _state, _data) do
    :ok
  end

  @doc false
  def callback_mode, do: :handle_event_function

  @doc false
  def code_change(_old_vsn, _old_state, _old_data, _extra), do: {:stop, :not_supported}
end
