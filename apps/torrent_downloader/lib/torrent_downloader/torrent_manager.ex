defmodule TorrentDownloader.TorrentManager do
  @moduledoc """
  Manages loaded torrents.  Supports adding tags to torrents and retrieving by tag.
  """
  use GenServer
  alias TorrentDownloader.{Config, NameRegistry, Torrent, TorrentsSupervisor}
  require Logger

  defmodule State do
    @moduledoc false
    defstruct [
      active_downloads: 0,
      download_limit: nil,
      active_uploads: 0,
      upload_limit: nil,
      max_download_speed: nil,
      max_upload_speed: nil
    ]

    def new(opts) do
      struct(__MODULE__, opts)
    end
  end

  @doc """
  Starts a torrent manager processes.
  """
  @spec start_link() :: GenServer.on_start
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Adds a new torrent to the system.
  """
  @spec add(String.t, String.t | nil) :: :ok | {:duplicate, Torrent.info_hash}
  def add(torrent_path, completion_dir \\ nil) do
    GenServer.call(__MODULE__, {:add, torrent_path, completion_dir})
  end

  @doc """
  Starts leeching or seeding a torrent.
  """
  @spec run(Torrent.info_hash) ::
    :ok |
    {:error, reason} when reason:
      :already_running |
      :upload_limit_reached |
      :download_limit_reached
  def run(info_hash) do
    GenServer.call(__MODULE__, {:run, info_hash})
  end

  @doc """
  Stop a torrent.
  """
  @spec stop(Torrent.info_hash) :: :ok | {:error, :not_running}
  def stop(info_hash) do
    GenServer.call(__MODULE__, {:stop, info_hash})
  end

  @doc """
  Lists all the torrent info hashes that are tagged with the specific tag, or all.
  """
  @spec list(:all | atom | [atom]) :: [String.t]
  def list(tag \\ :all)
  def list(tags) when is_list(tags) do
    :ets.foldl(fn {info_hash, _pid, _mon}, acc -> [info_hash|acc] end, [], __MODULE__)
  end
  def list(:all) do
    :ets.foldl(fn {info_hash, _pid, _mon}, acc -> [info_hash|acc] end, [], __MODULE__)
  end
  def list(tag) do
    :ets.foldl(fn {info_hash, _pid, _mon}, acc -> [info_hash|acc] end, [], __MODULE__)
  end

  @doc false
  def init([]) do
    table_path = Config.get(:torrents_table)

    {:ok, _} = :dets.open_file(__MODULE__, [file: table_path, auto_save: :infinity])
    :ets.new(__MODULE__, [:named_table, {:read_concurrency, true}])

    state =
      Config.get(:connection_limits)
      |> State.new()

    Process.send_after(self(), :init_saved, 1_500)
    {:ok, state}
  end

  @doc false
  def handle_call({:add, torrent_path, nil}, from, state) do
    completion_dir = Config.get(:completed) || raise "missing default completion directory"
    handle_call({:add, torrent_path, completion_dir}, from, state)
  end
  def handle_call({:add, torrent_path, completion_dir}, _from, state) do
    reply = add_to_dets_and_start(torrent_path, completion_dir)
    {:reply, reply, state}
  end
  def handle_call({:run, _info_hash}, _from, %{download_limit: max, active_downloads: max} = state)  do
    {:reply, {:error, :limit_reached}, state}
  end
  def handle_call({:run, info_hash}, _from, state) do
    max_downloads = state.download_limit
    max_uploads = state.upload_limit
    active_downloads = state.active_downloads
    active_uploads = state.active_uploads
    case Torrent.status(info_hash) do
      {:running, _} ->
        {:reply, {:error, :already_running}, state}
      {:not_running, :seeding} when active_uploads < max_uploads ->
        Torrent.run(info_hash)
        {:reply, :ok, %{state| active_uploads: state.active_uploads + 1}}
      {:not_running, :leeching} when active_downloads < max_downloads ->
        Torrent.run(info_hash)
        {:reply, :ok, %{state| active_downloads: state.active_downloads + 1}}
      {:not_running, :seeding} ->
        {:reply, {:error, :upload_limit_reached}, state}
      {:not_running, :leeching} ->
        {:reply, {:error, :download_limit_reached}, state}
    end
  end
  def handle_call({:stop, info_hash}, _from, state) do
    case Torrent.status(info_hash) do
      {:not_running, _} ->
        {:reply, {:error, :not_running}, state}
      {:running, :leeching} ->
        Torrent.stop(info_hash)
        {:reply, :ok, %{state| active_downloads: state.active_downloads - 1}}
      {:running, :seeding} ->
        Torrent.stop(info_hash)
        {:reply, :ok, %{state| active_uploads: state.active_downloads - 1}}
    end
  end

  @doc false
  def handle_info(:init_saved, state) do
    :dets.foldl(fn {torrent_path, completion_dir}, acc ->
      case TorrentsSupervisor.start_child(torrent_path, completion_dir) do
        {:ok, _} -> acc
        {:error, err} ->
          IO.inspect(err)
          [{torrent_path, completion_dir}|acc]
      end
    end, [], __MODULE__)
    |> Enum.each(&:dets.match_delete(__MODULE__, &1))
    :ok = :dets.sync(__MODULE__)
    Logger.debug("started saved torrents")
    {:noreply, state}
  end
  def handle_info({:register, NameRegistry, {:torrent, info_hash}, pid, nil}, state) do
    mon = Process.monitor(pid)
    :ets.insert(__MODULE__, {info_hash, pid, mon})
    {:noreply, state}
  end
  def handle_info({:register, NameRegistry, _name, _pid, nil}, state) do
    {:noreply, state}
  end
  def handle_info({:unregister, NameRegistry, _name, _pid}, state) do
    {:noreply, state}
  end
  def handle_info({:DOWN, mon, :process, pid, _reason}, state) do
    :ets.match_delete(__MODULE__, {:_, pid, mon})
    {:noreply, state}
  end
  def handle_info(msg, state) do
    IO.inspect msg
    {:noreply, state}
  end

  defp add_to_dets_and_start(torrent_path, completion_dir) do
    with true <- :dets.insert_new(__MODULE__, {torrent_path, completion_dir}),
         :dets.sync(__MODULE__),
         {:ok, _pid} <- TorrentsSupervisor.start_child(torrent_path, completion_dir)
    do
      :ok
    else
      false ->
        :ok
      {:error, reason} ->
        :dets.match_delete(__MODULE__, {torrent_path, completion_dir})
        :dets.sync(__MODULE__)
        {:error, reason}
    end
  end
end
