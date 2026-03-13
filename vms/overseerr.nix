{ lib, ... }:
let
  reg = (import ./vm-registry.nix).overseerr;
in
{
  imports = [
    ./base.nix
    ../modules/services/overseerr.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/overseerr";
            image = "overseerr-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  sys.services.overseerr = {
    enable = true;
    inherit (reg) port;
    openFirewall = false;
    reverseProxy.enable = false;
  };

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/overseerr 0755 overseerr overseerr -"
    ];

    services.overseerr = {
      serviceConfig = {
        DynamicUser = lib.mkForce false;
      };
    };
  };
}
