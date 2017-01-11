defmodule TorrentDownloader.Mixfile do
  use Mix.Project

  def project do
    [app: :torrent_downloader,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :torrex, :tracker_client, :gen_peer, :gen_stage],
     mod: {TorrentDownloader, []}]
  end

  defp deps do
    [{:torrex, in_umbrella: true},
     {:tracker_client, in_umbrella: true},
     {:gen_peer, in_umbrella: true},
     {:gen_stage, "~> 0.10.0"}]
  end
end
