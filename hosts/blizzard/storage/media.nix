let
  mediaStorage = import ../../../vms/media-storage.nix;
in
{
  systemd.tmpfiles.settings."10-torrent-permissions"."${mediaStorage.hostPath}/torrents".d = {
    mode = "2775";
    user = "-";
    group = "users";
  };
}
