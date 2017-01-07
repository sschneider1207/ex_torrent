defmodule TorrentDownloader.NameRegistry do
  @moduledoc """
  Registry for different types of torrent processes.
  """
  alias TorrentDownloader.Torrent
  alias TrackerClient.Peer

  @type via :: {:via, atom, {atom, term}}

  @doc """
  Starts a new torrent registry process.
  """
  @spec start_link(Registry.options) :: {:ok, pid} | {:error, term}
  def start_link(opts) do
    Registry.start_link(:unique, __MODULE__, opts)
  end

  @doc """
  Registers the calling process' name as a torrent by info hash.
  """
  @spec register_torrent(Torrent.info_hash) :: :ok | {:error, :duplicate}
  def register_torrent(info_hash) do
    Registry.register_name({__MODULE__, {:torrent, info_hash}}, self())
  end

  @doc false
  @spec torrent_via(Torrent.info_hash) :: via
  def torrent_via(info_hash) do
    {:via, Registry, {__MODULE__, {:torrent, info_hash}}}
  end

  @doc false
  @spec tracker_supervisor_via(Torrent.info_hash) :: via
  def tracker_supervisor_via(info_hash) do
    {:via, Registry, {__MODULE__, {:tracker_supervisor, info_hash}}}
  end

  @doc false
  @spec tracker_via(Torrent.info_hash, String.t) :: via
  def tracker_via(info_hash, url) do
    {:via, Registry, {__MODULE__, {:tracker, info_hash, url}}}
  end

  @doc false
  @spec peer_supervisor_via(Torrent.info_hash) :: via
  def peer_supervisor_via(info_hash) do
    {:via, Registry, {__MODULE__, {:peer_supervisor, info_hash}}}
  end

  @doc false
  @spec peer_pool_via(Torrent.info_hash) :: via
  def peer_pool_via(info_hash) do
    {:via, Registry, {__MODULE__, {:peer_pool, info_hash}}}
  end

  @doc false
  @spec peer_via(Torrent.info_hash, Peer.t) :: via
  def peer_via(info_hash, peer) do
    {:via, Registry, {__MODULE__, {:peer, info_hash, peer}}}
  end
end
