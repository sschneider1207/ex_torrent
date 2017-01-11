defmodule GenPeer.UTorrentTransportProtocol do
  @behaviour GenPeer
  alias GenPeer.UTorrentTransportProtocol.Packet

  @type t :: %__MODULE__{
    ip: :inet.ip_address,
    port: :inet.port_number,
    socket: :gen_udp.socket,
    max_window: non_neg_integer,
    cur_window: non_neg_integer,
    wnd_size: non_neg_integer,
    reply_micro: non_neg_integer,
    seq_nr: non_neg_integer,
    ack_nr: non_neg_integer
  }

  @type options :: [option]

  @type option :: {:max_window, non_neg_integer}

  defstruct [
    ip: nil,
    port: nil,
    socket: nil,
    max_window: 0,
    cur_window: 0,
    wnd_size: 0,
    reply_micro: nil,
    seq_nr: 1,
    ack_nr: nil,
    conn_id_rev: nil,
    conn_id_send: nil
  ]

  defmodule Data do
    @moduledoc false
    defstruct [:parent, :mon, :peer, :info_hash, :my_peer_id]
  end

  def connect(ip, port, info_hash, my_peer_id, options \\ [], timeout \\ 3_000) do
    me = self()
    :gen_statem.start(__MODULE__, [ip, port, info_hash, my_peer_id, options, timeout, me], [])
  end

  @doc false
  def init([ip, port, info_hash, my_peer_id, options, timeout, parent]) do
    with {:ok, peer} <- initiate_connection(ip, port, timeout),
         mon = Process.monitor(parent),
         data = struct(Data, [parent: parent, mon: mon, peer: peer, info_hash: info_hash, my_peer_id: my_peer_id])
    do
         IO.inspect(peer, label: "peer")
         {:ok, :connected, data}
    else
         err ->
           IO.inspect(err)
           {:stop, :connect_failed}
    end
  end

  defp initiate_connection(ip, port, timeout) do
    with {:ok, socket} <- :gen_udp.open(0, [:binary, {:reuseaddr, true}, {:active, false}]),
         seq_nr = 1,
         conn_id_rev = gen_conn_id(),
         conn_id_send = conn_id_rev + 1,
         syn_packet = Packet.new(:st_syn, conn_id_rev, 0, 0, seq_nr, 0),
         :ok <- :gen_udp.send(socket, ip, port, syn_packet),
         {:ok, {^ip, ^port, recv_packet}} <- :gen_udp.recv(socket, 20, timeout),
         parsed_packet = %{type: :st_state, conn_id: ^conn_id_rev} <- Packet.parse(recv_packet),
         IO.inspect(parsed_packet, label: "packet"),
         ack_nr = parsed_packet.ack_nr,
         seq_nr = seq_nr + 1,
         reply_micro = parsed_packet.reply_micro,
         wnd_size = parsed_packet.wnd_size,
         data_packet = Packet.new(:st_data, conn_id_send, reply_micro, 0, seq_nr, ack_nr),
         :ok <- :gen_udp.send(socket, ip, port, data_packet),
         :ok <- :inet.setopts(socket, [{:active, true}]),
         peer = struct(__MODULE__, [
           ip: ip,
           port: port,
           socket: socket,
           wnd_size: wnd_size,
           seq_nr: seq_nr + 1,
           ack_nr: ack_nr,
           reply_micro: reply_micro,
           conn_id_rev: conn_id_rev,
           conn_id_send: conn_id_send])
    do
         {:ok, peer}
    else
         err -> err
    end
  end

  defp gen_conn_id do
    <<conn_id :: 16-big-integer>> = :crypto.strong_rand_bytes(2)
    conn_id
  end

  @doc false
  def handle_event(:state_timeout, :syn_timeout, :cs_syn_sent, _data) do
    {:stop, :normal}
  end
  def handle_event(:info, {:DOWN, mon, :process, pid, _reason}, _state, %{mon: mon, parent: pid}) do
    {:stop, :normal}
  end
  def handle_event(_type, msg, _state, _data) do
    IO.inspect(msg, lablel: "unhandled msg")
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
