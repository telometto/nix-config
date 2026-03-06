{ ... }:
let
  reg = (import ./vm-registry.nix).lidarr;
  mediaShare = {
    source = "/rpool/unenc/media/data";
    mountPoint = "/data";
    tag = "media-data";
    proto = "virtiofs";
  };
in
{
  imports = [
    ./base.nix
    ../modules/services/lidarr.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/lidarr";
            image = "lidarr-state.img";
            size = 10240;
          }
        ];
        extraShares = [ mediaShare ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd.tmpfiles.rules = [
    "d /var/lib/lidarr 0700 lidarr lidarr -"
  ];

  sys.services.lidarr = {
    enable = true;
    port = reg.port;
    dataDir = "/var/lib/lidarr";
    reverseProxy.enable = false;
  };
}
