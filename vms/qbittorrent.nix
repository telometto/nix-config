{ pkgs, ... }:
let
  reg = (import ./vm-registry.nix).qbittorrent;
  mediaShare = {
    source = "/rpool/unenc/media/data";
    mountPoint = "/data";
    tag = "media-data";
    proto = "virtiofs";
  };
  vpnRoutes = [
    {
      Gateway = "10.100.0.1";
      Destination = "192.168.0.0/16";
    }
    {
      Gateway = "10.100.0.1";
      Destination = "10.100.0.0/24";
    }
  ];
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
        extraShares = [ mediaShare ];
        extraRoutes = vpnRoutes;
      }
    ))
  ];

  networking.firewall = {
    allowedTCPPorts = [
      reg.port
      50820
    ];
    allowedUDPPorts = [ 50820 ];
  };

  sys.services.qbittorrent = {
    enable = true;
    webinherit (reg) port;;
    torrentPort = 50820;
    dataDir = "/var/lib/qbittorrent";
    openFirewall = false;

    alternativeWebUI = {
      enable = true;
      package = pkgs.vuetorrent;
    };
  };
}
