defmodule TorrentDownloader.PeerSwarm do
  @moduledoc """
  Process that manages open connections to peers, and the states associated with said connections.
  """
  use GenServer
  alias TorrentDownloader.{NameRegistry, Torrent, TrackerRegistry}
  alias GenPeer.UTorrentTransportProtocol

  defmodule State do
    @moduledoc false

    defstruct [
      info_hash: nil,
      max_connections: 5,
      open_connections: 0,
      sockets: %{},
      peers: MapSet.new(),
      peer_refresh_interval: 3_000,
      my_peer_id: nil,
    ]

    def new(params) do
      struct(__MODULE__, params)
    end
  end

  @doc """
  Starts a new peer manager process.
  """
  @spec start_link(Torrent.info_hash, Torrent.peer_id) :: GenServer.on_start
  def start_link(info_hash, my_peer_id) do
    GenServer.start_link(__MODULE__, [info_hash, my_peer_id], [name: NameRegistry.peer_swarm_via(info_hash)])
  end

  @doc false
  def init([info_hash, my_peer_id]) do
    state = State.new(info_hash: info_hash, my_peer_id: my_peer_id)
    Process.send_after(self(), :refresh_peers, state.peer_refresh_interval)
    {:ok, state}
  end

  @doc false
  def handle_info(:refresh_peers, state) do
    peers =
      TrackerRegistry.peers(state.info_hash)
      |> Enum.reduce(state.peers, &MapSet.put(&2, &1))
    Enum.each(peers, fn peer ->
      UTorrentTransportProtocol.connect(peer.ip, peer.port, state.info_hash, state.my_peer_id)
    end)
    #Process.send_after(self(), :refresh_peers, state.peer_refresh_interval)
    {:noreply, %{state| peers: peers}}
  end
end
