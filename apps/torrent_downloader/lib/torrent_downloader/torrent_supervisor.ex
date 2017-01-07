defmodule TorrentDownloader.TorrentSupervisor do
  use Supervisor
  alias TorrentDownloader.{Torrent, TrackerSupervisor, Tracker}
  require Logger

  @doc """
  Starts a TorrentSupervisor process.
  """
  @spec start_link(Torrent.peer_id, String.t, String.t) :: Supervisor.on_start
  def start_link(peer_id, torrent_path, completion_dir) do
    Supervisor.start_link(__MODULE__, [peer_id, torrent_path, completion_dir])
  end

  @doc false
  def init([peer_id, torrent_path, completion_dir]) do
    me = self()
    children = [
      worker(Torrent, [torrent_path, completion_dir, peer_id, me])
    ]

    supervise(children, strategy: :rest_for_one)
  end

  @doc """
  Adds a `TorrentDownloader.TrackerSupervisor` process to the given supervisor's
  children list.  This process supervises the individual tracker processes.
  """
  @spec start_trackers(Supervisor.supervisor, Torrent.info_hash, [String.t], Keyword.t) :: Supervisor.on_start_child
  def start_trackers(sup, info_hash, tracker_urls, params) do
    spec = supervisor(TrackerSupervisor, [info_hash, tracker_urls, params])
    Supervisor.start_child(sup, spec)
  end
end
