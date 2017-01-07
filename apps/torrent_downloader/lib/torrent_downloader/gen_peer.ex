defmodule TorrentDownloader.GenPeer do

  def start_link(info_hash, peer_id, mod, peer) do
    mod.start_link(peer, info_hash, peer_id)
  end
end
