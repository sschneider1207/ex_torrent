defmodule TorrentDownloader.TorrentRegistry do
  @moduledoc """
  Registry for `TorrentDownloader.Torrent` processes to use to register their names
  as their info hash.
  """
  alias TorrentDownloader.Torrent

  @doc """
  Starts a new torrent registry process.
  """
  @spec start_link(Registry.options) :: {:ok, pid} | {:error, term}
  def start_link(opts) do
    Registry.start_link(:unique, __MODULE__, opts)
  end

  @doc """
  Registers the calling process' name as an info hash.
  """
  @spec register(Torrent.info_hash) :: :ok | {:error, :duplicate}
  def register(info_hash) do
    Registry.register_name({__MODULE__, info_hash}, self())
  end

  @doc false
  @spec via(Torrent.info_hash) :: {:via, atom, {atom, term}}
  def via(info_hash) do
    {:via, Registry, {__MODULE__, info_hash}}
  end
end
