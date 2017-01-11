defmodule GenPeer.UTorrentTransportProtocol.Packet do
  @moduledoc false

  @ver 1
  @extension 0

  defstruct [
    type: nil,
    ver: nil,
    extension: nil,
    conn_id: nil,
    ts_us: nil,
    ts_diff_us: nil,
    wnd_size: nil,
    seq_nr: nil,
    ack_nr: nil,
    reply_micro: nil,
    payload: <<>>
  ]

  def new(type, conn_id, ts_diff_us, wnd_size, seq_nr, ack_nr, payload \\ <<>>) do
    <<
      type_bits(type) :: 4-big-integer,
      @ver            :: 4-big-integer,
      @extension      :: 8-big-integer,
      conn_id         :: 16-big-integer,
      ts_us()         :: 32-big-integer,
      ts_diff_us      :: 32-big-integer,
      wnd_size        :: 32-big-integer,
      seq_nr          :: 16-big-integer,
      ack_nr          :: 16-big-integer,
      payload         :: binary
    >>
  end

  def parse(<<
    type_bits  :: 4-big-integer,
    ver        :: 4-big-integer,
    extension  :: 8-big-integer,
    conn_id    :: 16-big-integer,
    ts_us      :: 32-big-integer,
    ts_diff_us :: 32-big-integer,
    wnd_size   :: 32-big-integer,
    seq_nr     :: 16-big-integer,
    ack_nr     :: 16-big-integer,
    payload    :: binary
  >>) do
    struct(__MODULE__, [
      type: type(type_bits),
      ver: ver,
      extension: extension,
      conn_id: conn_id,
      ts_us: ts_us,
      ts_diff_us: ts_diff_us,
      wnd_size: wnd_size,
      seq_nr: seq_nr,
      ack_nr: ack_nr,
      reply_micro: ts_us() - ts_us,
      payload: payload
    ])
  end

  defp ts_us do
    <<ts_us :: 32-big-integer>> = <<System.os_time(:microseconds) - 1_484_099_000_000_000 :: 32-big-integer>>
    ts_us
  end

  defp type_bits(:st_data),  do: 0
  defp type_bits(:st_fin),   do: 1
  defp type_bits(:st_state), do: 2
  defp type_bits(:st_reset), do: 3
  defp type_bits(:st_syn),   do: 4

  defp type(0), do: :st_data
  defp type(1), do: :st_fin
  defp type(2), do: :st_state
  defp type(3), do: :st_reset
  defp type(4), do: :st_syn
end
