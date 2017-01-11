defmodule TorrentDownloader.TorrentSupervisor do
  @moduledoc """
  Process that supervises any process related to a specific torrent.
  """
  use Supervisor
  alias TorrentDownloader.{PeerSwarm, Torrent, TrackerSupervisor}
  require Logger

  @doc """
  Starts a TorrentSupervisor process.
  """
  @spec start_link(Torrent.peer_id, String.t, String.t) :: Supervisor.on_start
  def start_link(peer_id, torrent_path, completion_dir) do
    case Torrex.decode(torrent_path) do
      {:ok, torrent} ->
        Supervisor.start_link(__MODULE__, [peer_id, torrent, completion_dir])
      err ->
        err
    end
  end

  @doc false
  def init([peer_id, torrent, completion_dir]) do
    info_hash = info_hash(torrent["info"])
    children = [
      supervisor(TrackerSupervisor, [info_hash]),
      worker(Torrent, [info_hash, torrent, completion_dir, peer_id]),
      worker(PeerSwarm, [info_hash, peer_id]),
    ]

    supervise(children, strategy: :one_for_all)
  end

  defp info_hash(info) do
    encoded = Benx.encode(info)
    :crypto.hash(:sha, encoded)
  end
end
