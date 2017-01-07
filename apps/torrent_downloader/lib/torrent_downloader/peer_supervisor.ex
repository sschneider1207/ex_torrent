alias Experimental.DynamicSupervisor
defmodule TorrentDownloader.PeerSupervisor do
  @moduledoc """
  Dyanmic supervisor for peer processes.

  Children are `TorrentDownloader.PeerPool.*` processes.
  """

  alias TorrentDownloader.{GenPeer, NameRegistry, Torrent}
  use DynamicSupervisor

  @doc """
  Starts a PeerSupervisor process.
  """
  @spec start_link(Torrent.info_hash, Torrent.peer_id) :: Supervisor.on_start
  def start_link(info_hash, peer_id) do
    DynamicSupervisor.start_link(__MODULE__, [info_hash, peer_id], [name: NameRegistry.peer_supervisor_via(info_hash)])
  end

  @doc """
  Starts a new child process with the given torrent and completion directory as arguments.
  """
  @spec start_child(Torrent.info_hash, String.t, String.t) :: Supervisor.on_start_child
  def start_child(info_hash, mod, peer) do
    DynamicSupervisor.start_child(NameRegistry.peer_supervisor_via(info_hash), [mod, peer])
  end

  @doc false
  def init([info_hash, peer_id]) do

    children = [
      worker(GenPeer, [info_hash, peer_id], restart: :temporary)
    ]

    {:ok, children, strategy: :one_for_one}
  end
end
