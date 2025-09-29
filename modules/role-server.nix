{ lib, config, ... }:
let
  cfg = config.telometto.role.server;
in
{
  config = lib.mkIf cfg.enable {
    telometto = {
      boot = {
        lanzaboote.enable = lib.mkDefault true;
        plymouth.enable = lib.mkDefault true;
      };

      networking = {
        base.enable = lib.mkDefault true;
        networkd.enable = lib.mkDefault true;
        firewall.enable = lib.mkDefault true;
      };

      # Core services for server systems
      services = {
        openssh.enable = lib.mkDefault true;
        timesyncd.enable = lib.mkDefault true;
        resolved.enable = lib.mkDefault true;
        maintenance.enable = lib.mkDefault true;
        autoUpgrade.enable = lib.mkDefault true;
        nfs.server.openFirewall = lib.mkDefault true;
      };
    };

    # Enable home-manager with minimal configuration for server users
    telometto.home.enable = lib.mkDefault true;
  };
}
