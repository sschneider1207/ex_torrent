defmodule TorrentDownloader.TrackerRegistry do
  @moduledoc """
  Registry process for `TorrentDownloader.Tracker` processes to use to
  register under an info hash.
  """

  alias TorrentDownloader.{Torrent, Tracker}

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
  All trackers registered under `info_hash` start making announcements.
  """
  @spec start_announcing(Torrent.info_hash) :: :ok
  def start_announcing(info_hash) do
    broadcast(info_hash, &Tracker.start_announcing/1)
  end

  @doc """
  All trackers registered under `info_hash` stop making announcements.
  """
  @spec stop_announcing(Torrent.info_hash) :: :ok
  def stop_announcing(info_hash) do
    broadcast(info_hash, &Tracker.stop_announcing/1)
  end

  defp broadcast(info_hash, function) do
    Registry.lookup(__MODULE__, info_hash)
    |> Enum.map(fn {pid, _val} -> pid end)
    |> Enum.each(function)
    :ok
  end

  def peers(info_hash) do
    Registry.lookup(__MODULE__, info_hash)
    |> Enum.map(fn {pid, _val} -> pid end)
    |> Enum.map(&Tracker.peers/1)
    |> List.flatten()
  end
end
