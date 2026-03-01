{ lib, config, ... }:
let
  cfg = config.sys.role.server;
in
{
  config = lib.mkIf cfg.enable {
    sys = {
      home.enable = true;

      boot = {
        lanzaboote.enable = true;
        plymouth.enable = false;
      };

      networking = {
        base.enable = true;
        networkd.enable = true;
      };

      programs.ssh.enable = true;

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
          sshKeyPath = "/root/.ssh/nix-config-deploy";
        };

        nfs.server.openFirewall = false;
        tailscale.enable = true;
      };
    };

    networking.firewall.enable = true;
  };
}
