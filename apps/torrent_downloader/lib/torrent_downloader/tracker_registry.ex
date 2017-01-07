defmodule TorrentDownloader.TrackerRegistry do
  @moduledoc """
  Registry process for `TorrentDownloader.Tracker` processes to use to
  register under an info hash.
  """

  alias TorrentDownloader.{Torrent, Tracker}
  alias TrackerClient.AnnounceResponse

  @doc """
  Starts a new tracker registry process.
  """
  @spec start_link(Registry.options) :: {:ok, pid} | {:error, term}
  def start_link(opts) do
    Registry.start_link(:duplicate, __MODULE__, opts)
  end

  @doc """
  Registers the calling process under the given info hash and url.
  """
  @spec register(Torrent.info_hash, String.t) :: :ok
  def register(info_hash, url) do
    Registry.register(__MODULE__, info_hash, url)
  end

  @doc """
  All trackers registered under `info_hash` start making announcements using the provided
  params as initial announcement parameters.
  """
  @spec start_announcing(Torrent.info_hash) :: :ok
  def start_announcing(info_hash) do
    Registry.lookup(__MODULE__, info_hash)
    |> Enum.map(fn {pid, _val} -> pid end)
    |> Enum.each(&Tracker.start_announcing/1)
    :ok
  end
end
