defmodule TorrentDownloader.Torrent do
  @moduledoc """
  Process for managing a torrent file.
  """
  @behaviour :gen_statem
  alias TorrentDownloader.{Config, NameRegistry, TorrentSupervisor, TrackerRegistry, TrackerSupervisor}

  defmodule Data do
    @moduledoc false

    defstruct [
      peer_id: nil,
      torrent_dir: nil,
      torrent: nil,
      in_progress_file: nil,
      info_hash: nil,
      tracker_urls: [],
      total_size: 0,
      downloaded: 0,
      left: 0,
      uploaded: 0,
      compact: true,
    ]

    def new(opts) do
      struct(__MODULE__, opts)
    end
  end

  @opaque t :: %Data{}

  @type info_hash :: <<_ :: 20>>

  @type peer_id :: <<_ :: 20>>

  @doc """
  Starts a new torrent state machine.
  """
  @spec start_link(info_hash, map, String.t, peer_id) :: :gen_statem.start_ret()
  def start_link(info_hash, torrent, completion_dir, peer_id) do
    :gen_statem.start_link(NameRegistry.torrent_via(info_hash), __MODULE__, [info_hash, torrent, completion_dir, peer_id], [])# [{:debug, [:trace, :debug]}])
  end

  @doc """
  Starts leeching or seeding a torrent.
  """
  @spec run(info_hash) :: :ok
  def run(info_hash) do
    :gen_statem.cast(NameRegistry.torrent_via(info_hash), :run)
  end

  @doc """
  Stops a torrent from running.
  """
  @spec stop(info_hash) :: :ok
  def stop(info_hash) do
    :gen_statem.cast(NameRegistry.torrent_via(info_hash), :stop)
  end

  @doc """
  Get download/upload/remaining stats from a torrent process.
  """
  @spec stats(info_hash) :: Keyword.t
  def stats(info_hash) do
    :gen_statem.call(NameRegistry.torrent_via(info_hash), :stats)
  end

  @doc """
  Retrieves status of the torrent.
  """
  @spec status(info_hash) :: {:running | :not_running, :leeching | :seeding}
  def status(info_hash) do
    :gen_statem.call(NameRegistry.torrent_via(info_hash), :status)
  end

  @doc false
  def init([info_hash, torrent, completion_dir, peer_id]) do
    with tracker_urls = trackers(torrent),
         {:ok, total_size} <- total_size(torrent["info"]),
         in_progress_name = in_progress_name(info_hash),
         in_progress_file = Path.join(completion_dir, in_progress_name),
         :ok <- File.touch!(in_progress_file),
         {:ok, %{size: downloaded}} <- File.stat(in_progress_file),
         left = total_size - downloaded,
         data = Data.new([
           torrent: torrent,
           info_hash: info_hash,
           completion_dir: completion_dir,
           peer_id: peer_id,
           in_progress_file: in_progress_file,
           tracker_urls: tracker_urls,
           total_size: total_size,
           downloaded: downloaded,
           left: left])
    do
      send(self(), :init_trackers)
      {:ok, :trackers_not_started, data}
    else
      :no ->
        {:stop, {:error, :duplicate}}
      {:error, reason} ->
        {:stop, {:error, reason}}
    end
  end

  defp trackers(info) do
    (info["announce-list"] || [info["announce"]])
    |> List.flatten()
  end

  defp total_size(%{"length" => length}), do: {:ok, length}
  defp total_size(%{"files" => files}) do
    length =
      files
      |> Enum.map(&Map.get(&1, "length"))
      |> Enum.sum()
    {:ok, length}
  end
  defp total_size(x), do: IO.inspect(x); {:error, "torrent is missing length field(s)"}

  defp in_progress_name(info_hash) do
    info_hash
    |> Base.encode16(case: :lower)
    |> Kernel.<>(".inprogress")
  end

  def handle_event({:call, from}, :status, state, data) do
    running = case state do
      :not_running -> :not_running
      _ -> :running
    end
    type = case data.left do
      0 -> :seeding
      _ -> :leeching
    end
    {:keep_state_and_data, {:reply, from, {running, type}}}
  end
  def handle_event({:call, from}, :stats, _state, data) do
    reply = [
      uploaded: data.uploaded,
      downloaded: data.downloaded,
      left: data.left
    ]
    {:keep_state_and_data, {:reply, from, reply}}
  end
  def handle_event(:cast, :run, :not_running, data) do
    TrackerRegistry.start_announcing(data.info_hash)
    next_state = case data.left do
      0 -> :seeding
      _ -> :leeching
    end
    {:next_state, next_state, data}
  end
  def handle_event(:cast, :run, state, _data) when state in [:seeding, :leeching] do
    :keep_state_and_data
  end
  def handle_event(:cast, :stop, :not_running, _data) do
    :keep_state_and_data
  end
  def handle_event(:cast, :stop, state, data) when state in [:seeding, :leeching] do
    TrackerRegistry.stop_announcing(data.info_hash)
    {:next_state, :not_running, data}
  end
  def handle_event(:info, :init_trackers, :trackers_not_started, data) do
    params = [
      peer_id: data.peer_id,
      port: Config.get(:port)
    ]
    Enum.each(data.tracker_urls, &TrackerSupervisor.start_child(data.info_hash, &1, params))
    {:next_state, :not_running, data}
  end

  @doc false
  def terminate(_reason, _state, _data) do
    :ok
  end

  @doc false
  def callback_mode, do: :handle_event_function

  @doc false
  def code_change(_old_vsn, _old_state, _old_data, _extra), do: {:stop, :not_supported}
end
