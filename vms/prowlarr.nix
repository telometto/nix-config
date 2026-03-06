_:
let
  reg = (import ./vm-registry.nix).prowlarr;
in
{
  imports = [
    ./base.nix
    ../modules/services/prowlarr.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/prowlarr";
            image = "prowlarr-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [
    reg.port # prowlarr
    11013 # flaresolverr
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/prowlarr 0700 prowlarr prowlarr -"
  ];

  sys.services.prowlarr = {
    enable = true;
    port = reg.port;
    dataDir = "/var/lib/prowlarr";
    reverseProxy.enable = false;
  };

  services.flaresolverr = {
    enable = true;
    port = 11013;
  };
}
