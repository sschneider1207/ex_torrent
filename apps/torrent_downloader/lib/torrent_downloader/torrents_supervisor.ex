alias Experimental.DynamicSupervisor
defmodule TorrentDownloader.TorrentsSupervisor do
  @moduledoc """
  Dyanmic supervisor for torrents.

  Children are `TorrentDownloader.TorrentSupervisor` processes that supervise
  the actual torrent process, and it's trackers.
  """

  alias TorrentDownloader.{TorrentSupervisor}
  use DynamicSupervisor
  @client "EX"
  @version "0001"

  @doc """
  Starts a TorrentsSupervisor process.
  """
  @spec start_link :: Supervisor.on_start
  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  @doc false
  def init([]) do
    peer_id = peer_id()

    children = [
      worker(TorrentSupervisor, [peer_id], restart: :transient)
    ]

    {:ok, children, strategy: :one_for_one}
  end

  defp peer_id do
    "-" <> @client <> @version <> "-" <> :crypto.strong_rand_bytes(12)
  end

  @doc """
  Starts a new child process with the given torrent and completion directory as arguments.
  """
  @spec start_child(String.t, String.t) :: Supervisor.on_start_child
  def start_child(torrent_path, completion_dir) do
    DynamicSupervisor.start_child(__MODULE__, [torrent_path, completion_dir])
  end
end
