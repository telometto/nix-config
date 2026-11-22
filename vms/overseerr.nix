{ lib, consts, ... }:
let
  reg = (import ./vm-registry.nix { inherit consts; }).overseerr;
in
{
  imports = [
    ./base.nix
    ../modules/services/seerr.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            # Keep the existing VM identity and disk for Seerr's automatic
            # Overseerr migration. See ../docs/seerr.md before the first start.
            mountPoint = "/var/lib/overseerr";
            image = "overseerr-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  sys.services.seerr = {
    enable = true;
    inherit (reg) port;
    openFirewall = false;
    reverseProxy.enable = false;
  };

  services.seerr.configDir = "/var/lib/overseerr";

  users.groups.seerr = { };
  users.users.seerr = {
    isSystemUser = true;
    group = "seerr";
  };

  systemd.services.seerr.serviceConfig = {
    # The state volume is a mount point, so it must not be relocated into
    # /var/lib/private by DynamicUser. StateDirectory also fixes ownership of
    # the existing data before the unprivileged service starts.
    DynamicUser = lib.mkForce false;
    User = "seerr";
    Group = "seerr";
    StateDirectory = lib.mkForce "overseerr";
    StateDirectoryMode = "0700";
  };
}
