_:
let
  reg = (import ./vm-registry.nix).bazarr;
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
    ../modules/services/bazarr.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/bazarr";
            image = "bazarr-state.img";
            size = 10240;
          }
        ];
        extraShares = [ mediaShare ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd.tmpfiles.rules = [
    "d /var/lib/bazarr 0700 bazarr bazarr -"
  ];

  sys.services.bazarr = {
    enable = true;
    port = reg.port;
    dataDir = "/var/lib/bazarr";
    reverseProxy.enable = false;
  };
}
