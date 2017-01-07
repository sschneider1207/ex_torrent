defmodule TorrentDownloader do
  use Application
  alias TorrentDownloader.{Config, NameRegistry, TrackerRegistry, TorrentManager, TorrentsSupervisor}

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    main_dir = Application.get_env(:torrent_downloader, :main_dir)
    unless File.dir?(main_dir), do: raise "Main directory `#{main_dir}` not found"

    children = [
      worker(Config, [main_dir]),
      worker(TorrentManager, []),
      supervisor(NameRegistry, [[listeners: [TorrentManager]]]),
      supervisor(TrackerRegistry, [[]]),
      supervisor(TorrentsSupervisor, []),
    ]

    opts = [strategy: :one_for_all, name: TorrentDownloader.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
