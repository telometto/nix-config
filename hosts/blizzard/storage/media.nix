{
  systemd.tmpfiles.settings."10-torrent-permissions"."/rpool/unenc/media/data/torrents".d = {
    mode = "2775";
    user = "-";
    group = "users";
  };
}
