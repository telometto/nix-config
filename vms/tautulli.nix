{ ... }:
let
  reg = (import ./vm-registry.nix).tautulli;
in
{
  imports = [
    ./base.nix
    ../modules/services/tautulli.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/tautulli";
            image = "tautulli-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd.tmpfiles.rules = [
    "d /var/lib/tautulli 0700 plexpy nogroup -"
  ];

  sys.services.tautulli = {
    enable = true;
    port = reg.port;
    dataDir = "/var/lib/tautulli";
    configFile = "/var/lib/tautulli/config.ini";
    reverseProxy.enable = false;
  };
}
