{
  config,
  lib,
  pkgs,
  consts,
  ...
}:
let
  reg = (import ./vm-registry.nix { inherit consts; }).qbittorrent;
  mediaStorage = import ./media-storage.nix;
  networkDefaults = import ./microvm-network-defaults.nix;
in
{
  imports = [
    ./base.nix
    ../modules/services/qbittorrent.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/qbittorrent";
            image = "qbittorrent-state.img";
            size = 10240;
          }
        ];
        extraShares = [ mediaStorage.share ];
        extraRoutes = networkDefaults.vpnReturnRoutes;
      }
    ))
  ];

  networking.firewall = {
    allowedTCPPorts = [
      reg.port
      consts.ports.network.qbittorrentTorrent
    ];
    allowedUDPPorts = [ consts.ports.network.qbittorrentTorrent ];
  };

  # New downloads use the shared media group; account/state ownership stays private.
  systemd.services.qbittorrent.serviceConfig = {
    Group = lib.mkForce "users";
    SupplementaryGroups = lib.mkForce [ config.sys.services.qbittorrent.group ];
  };

  sys.services.qbittorrent = {
    enable = true;
    webPort = reg.port;
    torrentPort = consts.ports.network.qbittorrentTorrent;
    dataDir = "/var/lib/qbittorrent";
    openFirewall = false;

    alternativeWebUI = {
      enable = true;
      package = pkgs.vuetorrent;
    };
  };
}
