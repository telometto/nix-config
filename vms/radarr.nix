{ ... }:
let
  reg = (import ./vm-registry.nix).radarr;
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
    ../modules/services/radarr.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/radarr";
            image = "radarr-state.img";
            size = 10240;
          }
        ];
        extraShares = [ mediaShare ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd.tmpfiles.rules = [
    "d /var/lib/radarr 0700 radarr radarr -"
  ];

  sys.services.radarr = {
    enable = true;
    port = reg.port;
    dataDir = "/var/lib/radarr";
    reverseProxy.enable = false;
  };
}
