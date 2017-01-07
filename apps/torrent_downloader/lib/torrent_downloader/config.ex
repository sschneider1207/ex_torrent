defmodule TorrentDownloader.Config do
  @moduledoc """
  Process for managing the config for the system via a `.config` file located
  in the main directory.
  """
  use GenServer
  require Logger

  @spec start_link(String.t) :: GenServer.on_start
  def start_link(main_dir) do
    GenServer.start_link(__MODULE__, [main_dir], name: __MODULE__)
  end

  @doc """
  Gets the value for a config property.
  """
  @spec get(atom) :: term
  def get(key) do
    try do
      :ets.lookup_element(__MODULE__, key, 2)
    rescue
      _ -> nil
    end
  end

  @spec completed_dir() :: String.t
  def completed_dir, do: :ets.lookup_element(__MODULE__, :completed, 2)

  @spec port() :: non_neg_integer
  def port, do: :ets.lookup_element(__MODULE__, :port, 2)

  @spec connection_limits() :: Keyword.t
  def connection_limits, do: :ets.lookup_element(__MODULE__, :connection_limits, 2)

  @doc false
  def init([main_dir]) do
    :ets.new(__MODULE__, [:named_table, {:read_concurrency, true}])

    config_path = init_config(main_dir)
    sync_disk_to_table(config_path)
    init_directories(main_dir)
    init_port()
    init_connection_limits()
    sync_table_to_disk(config_path)

    {:ok, config_path}
  end

  defp init_config(main_dir) do
    config_path = Path.join(main_dir, ".config")
    unless File.exists?(config_path), do: File.touch!(config_path)
    config_path
  end

  defp init_directories(main_dir) do
    lookup_or_set(:torrents_table, fn -> Path.join(main_dir, ".torrents") |> String.to_char_list() end)

    completed_dir = lookup_or_set(:completed, fn -> Path.join(main_dir, "completed") end)
    unless File.exists?(completed_dir), do: File.mkdir!(completed_dir)
  end

  defp init_port do
    lookup_or_set(:port, fn -> 6886 end)
  end

  defp init_connection_limits do
    lookup_or_set(:connection_limits, fn -> [
      download_limit: 5,
      upload_limit: 5,
      max_download_speed: nil,
      max_upload_speed: nil
      ] end)
  end

  defp lookup_or_set(key, default) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, val}] ->
        val
      _ ->
        val = default.()
        :ets.insert(__MODULE__, {key, val})
        val
    end
  end

  defp sync_table_to_disk(path) do
    __MODULE__
    |> :ets.tab2list()
    |> write_terms(path)
    :ok
  end

  defp sync_disk_to_table(path) do
    case :file.consult(path) do
      {:ok, terms} -> :ets.insert(__MODULE__, terms)
      {:error, term} -> Logger.warn("error reading config", path: path, reason: term)
    end
  end

  defp write_terms(terms, path) do
    text =
      terms
      |> Enum.map(&:io_lib.format('~tp.~n', [&1]))
    path
    |> String.to_char_list()
    |> :file.write_file(text)
    :ok
  end
end
