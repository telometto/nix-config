_:
let
  reg = (import ./vm-registry.nix).readarr;
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
    ../modules/services/readarr.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/readarr";
            image = "readarr-state.img";
            size = 10240;
          }
        ];
        extraShares = [ mediaShare ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd.tmpfiles.rules = [
    "d /var/lib/readarr 0700 readarr readarr -"
  ];

  sys.services.readarr = {
    enable = true;
    inherit (reg) port;
    dataDir = "/var/lib/readarr";
    reverseProxy.enable = false;
  };
}
