defmodule TorrentDownloader.TrackerSupervisor do
  @moduledoc """
  Supervisor for tracker processes.
  """
  use Supervisor
  alias TorrentDownloader.{Torrent, Tracker}

  @doc """
  Starts a new TrackerSupervisor process.
  """
  @spec start_link(Torrent.info_hash, [String.t], Keyword.t) :: Supervisor.on_start
  def start_link(info_hash, tracker_urls, params) do
    Supervisor.start_link(__MODULE__, [info_hash, tracker_urls, params])
  end

  @doc false
  def init([info_hash, tracker_urls, params]) do
    children = for {tracker_url, i} <- Enum.with_index(tracker_urls) do
      worker(Tracker, [info_hash, tracker_url, params], id: Module.concat(Tracker, to_string(i)))
    end

    supervise(children, strategy: :one_for_one)
  end
end
