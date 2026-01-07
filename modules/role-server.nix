{ lib, config, ... }:
let
  cfg = config.sys.role.server;
in
{
  config = lib.mkIf cfg.enable {
    sys = {
      boot = {
        lanzaboote.enable = true;
        plymouth.enable = false;
      };

      networking = {
        base.enable = true;
        networkd.enable = true;
      };

      services = {
        openssh = {
          enable = true;
          openFirewall = true;
        };

        timesyncd.enable = true;
        resolved.enable = true;
        maintenance.enable = true;

        autoUpgrade = {
          enable = true;
          dates = "monthly";
        };

        nfs.server.openFirewall = false;
        tailscale.enable = true;
      };
    };

    sys.home.enable = true;

    networking.firewall.enable = true;
  };
}
