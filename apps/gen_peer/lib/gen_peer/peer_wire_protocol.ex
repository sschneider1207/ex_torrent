defmodule GenPeer.PeerWireProtocol do
  @behaviour GenPeer
  @behaviour :gen_statem
  @pstr "BitTorrent protocol"

  @type t :: %__MODULE__{
    ip: :inet.ip_address,
    port: :inet.port_number,
    socket: :gen_tcp.socket,
    choked: boolean,
    interested: boolean
  }

  @type options :: [option]

  @type option :: term

  defstruct [
    ip: nil,
    port: nil,
    socket: nil,
    choked: true,
    interested: false
  ]

  defmodule Data do
    @moduledoc false
    defstruct [:parent, :mon, :peer, :info_hash, :my_peer_id]
  end

  def connect(ip, port, info_hash, my_peer_id, options \\ [], timeout \\ 5_000) do
    me = self()
    :gen_statem.start(__MODULE__, [ip, port, info_hash, my_peer_id, options, timeout, me], [])
  end

  @doc false
  def init([ip, port, info_hash, my_peer_id, options, timeout, parent]) do
    packet = <<
      String.length(@pstr) :: 8-big-integer,
      @pstr :: binary,
      0 :: size(64),
      info_hash :: binary,
      my_peer_id :: binary
    >>
    with {:ok, socket} <- :gen_tcp.connect(ip, port, [:binary, {:reuseaddr, true}], timeout),
         :ok           <- :gen_tcp.send(socket, packet),
         :ok           <- :inet.setopts(socket, [{:packet, 4}]),
         peer          = struct(__MODULE__, options ++ [ip: ip, port: port, socket: socket]),
         mon           = Process.monitor(parent),
         data         = struct(Data, [parent: parent, mon: mon, peer: peer, info_hash: info_hash, my_peer_id: my_peer_id])
    do
         {:ok, :connected, data}
    else
         _ -> {:stop, :handshake_failed}
    end
  end

  @doc false
  def handle_event(:info, {:DOWN, mon, :process, pid, _reason}, _state, %{mon: mon, parent: pid}) do
    {:stop, :normal}
  end
  def handle_event(type, msg, state, data) do
    :keep_state_and_data
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
