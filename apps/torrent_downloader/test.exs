alias TorrentDownloader.{TorrentManager}

:timer.sleep(2_000)

[h] = TorrentManager.list()
TorrentManager.run(h)
