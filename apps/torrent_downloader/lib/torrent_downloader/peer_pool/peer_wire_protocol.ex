defmodule TorrentDownloader.PeerPool.PeerWireProtocol do
  @behaviour :gen_statem
  @pstr "BitTorrent protocol"
  alias TorrentDownloader.{NameRegistry}

  defmodule State do
    @moduledoc false

    defstruct [
      am_choking: true,
      am_interested: false,
      peer_choking: true,
      peer_interested: false
    ]

    def new do
      struct(__MODULE__, [])
    end
  end

  defmodule Data do
    @moduledoc false

    defstruct [
      socket: nil,
      info_hash: nil,
      my_peer_id: nil,
      peer: nil
    ]

    def new(params) do
      struct(__MODULE__, params)
    end
  end

  def start_link(peer, info_hash, my_peer_id) do
    :gen_statem.start_link(__MODULE__, [peer, info_hash, my_peer_id], [])
  end

  @doc false
  def init([peer, info_hash, my_peer_id]) do
    :ok = :pg2.join({:peer_pool, info_hash}, self())
    data = Data.new(peer: peer, info_hash: info_hash, my_peer_id: my_peer_id)
    send(self(), :handshake)
    {:ok, :not_connected, data}
  end

  @doc false
  def handle_event(:info, :handshake, :not_connected, data) do
    case handshake(data.peer, data.info_hash, data.my_peer_id) do
      {:ok, socket} ->
        state = State.new()
        {:next_state, state, %{data| socket: socket}}
      {:error, reason} ->
        {:stop, reason}
    end
  end
  def handle_event(:info, {:tcp_closed, socket}, _state, %{socket: socket}) do
    {:stop, :tcp_closed}
  end
  def handle_event(:info, msg, _state, _data) do
    IO.inspect msg
    :keep_state_and_data
  end

  defp handshake(peer, info_hash, my_peer_id) do
    packet = <<
      String.length(@pstr) :: 8-big-integer,
      @pstr :: binary,
      0 :: size(64),
      info_hash :: binary,
      my_peer_id :: binary
    >>
    with {:ok, socket} <- :gen_tcp.connect(peer.ip, peer.port, [:binary, {:reuseaddr, true}], 5_000),
         :ok           <- :gen_tcp.send(socket, packet),
         :ok           <- :inet.setopts(socket, [{:packet, 4}])
    do
         {:ok, socket}
    else
         _ -> {:error, :handshake_failed}
    end
  end

  @doc false
  def terminate(_reason, _state, _data) do
    :ok
  end

  @doc false
  def callback_mode, do: :handle_event_function

  @doc false
  def code_change(_old_vsn, _old_state, _old_data, _extra), do: {:stop, :not_supported}
end
