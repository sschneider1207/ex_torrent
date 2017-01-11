defmodule GenPeer do
  alias GenPeer.{PeerWireProtocol, UTorrentTransportProtocol}

  @type t :: PeerWireProtocol.t | UTorrentTransportProtocol.t

  @type options :: PeerWireProtocol.options | UTorrentTransportProtocol.options

  @type info_hash :: <<_ :: 20>>

  @type peer_id :: <<_ :: 20>>

  @callback connect(
    ip         :: :inet.ip_address,
    port       :: :inet.port_number,
    info_hash  :: info_hash,
    my_peer_id :: peer_id,
    options    :: options,
    timeout    :: non_neg_integer
  ) :: {:ok, t} | {:error, term}
end
