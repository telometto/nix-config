# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:

{
  services.tautulli = {
    enable = true;

    # port = 8181; # Default port: 8181

    openFirewall = true;
    # user = VARS.users.serverAdmin.user; # If not set, the service will run as user "tautulli"
    # group = "nogroup"; # Default: "nogroup"
    dataDir = "/rpool/unenc/apps/nixos/tautulli"; # If not set, the service will use the default data directory
    # configFile = "/var/lib/plexpy/config.ini"; # Default: "/var/lib/plexpy/config.ini"
  };

  environment.systemPackages = with pkgs; [ tautulli ];
}
