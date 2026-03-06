_:
let
  registry = import ./vm-registry.nix;
  reg = registry.prowlarr;
  flaresolverrPort = registry.flaresolverr.port;
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
    flaresolverrPort
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/prowlarr 0700 prowlarr prowlarr -"
  ];

  sys.services.prowlarr = {
    enable = true;
    inherit (reg) port;
    dataDir = "/var/lib/prowlarr";
    reverseProxy.enable = false;
  };

  services.flaresolverr = {
    enable = true;
    port = flaresolverrPort;
  };
}
