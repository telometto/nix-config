{ ... }:
let
  reg = (import ./vm-registry.nix).ombi;
in
{
  imports = [
    ./base.nix
    ../modules/services/ombi.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/ombi";
            image = "ombi-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd.tmpfiles.rules = [
    "d /var/lib/ombi 0700 ombi ombi -"
  ];

  sys.services.ombi = {
    enable = true;
    port = reg.port;
    dataDir = "/var/lib/ombi";
    reverseProxy.enable = false;
  };
}
