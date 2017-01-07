alias Experimental.DynamicSupervisor
defmodule TorrentDownloader.TrackerSupervisor do
  @moduledoc """
  Supervisor for tracker processes.
  """
  use DynamicSupervisor
  alias TorrentDownloader.{NameRegistry, Torrent, Tracker}

  @doc """
  Starts a new TrackerSupervisor process.
  """
  @spec start_link(Torrent.info_hash) :: Supervisor.on_start
  def start_link(info_hash) do
    DynamicSupervisor.start_link(__MODULE__, [info_hash], [name: NameRegistry.tracker_supervisor_via(info_hash)])
  end

  @doc """
  Starts a new supervised tracker.
  """
  @spec start_child(Torrent.info_hash, [String.t], Keyword.t) :: Supervisor.on_child_start
  def start_child(info_hash, tracker_url, params) do
    DynamicSupervisor.start_child(NameRegistry.tracker_supervisor_via(info_hash), [tracker_url, params])
  end

  @doc false
  def init([info_hash]) do
    children = [
      worker(Tracker, [info_hash])
    ]

    {:ok, children, strategy: :one_for_one}
  end
end
