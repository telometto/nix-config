{ ... }:
let
  reg = (import ./vm-registry.nix).sonarr;
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
    ../modules/services/sonarr.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/sonarr";
            image = "sonarr-state.img";
            size = 10240;
          }
        ];
        extraShares = [ mediaShare ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd.tmpfiles.rules = [
    "d /var/lib/sonarr 0700 sonarr sonarr -"
  ];

  sys.services.sonarr = {
    enable = true;
    port = reg.port;
    dataDir = "/var/lib/sonarr";
    reverseProxy.enable = false;
  };
}
