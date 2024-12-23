# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:

{
  services.ombi = {
    enable = true;

    # port = 5000; # Default port: 5000

    openFirewall = true;
    # user = VARS.users.serverAdmin.user; # If not set, the service will run as user "ombi"
    # group = "ombi"; # Default: "ombi"
    dataDir = "/rpool/unenc/apps/nixos/ombi"; # If not set, the service will use the default data directory
  };

  environment.systemPackages = with pkgs; [ ombi ];
}
