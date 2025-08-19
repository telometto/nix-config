# Host-specific system configuration defaults
{ config, lib, pkgs, pkgs-unstable, VARS, ... }:

{
  services.plex = {
    enable = true;

    openFirewall = true;
    # user = VARS.users.admin.user; # If not set, the service will run as user "plex"
    # dataDir = "/rpool/unenc/apps/nixos/plex"; # If not set, the service will use the default data directory
    package = pkgs-unstable.plex;
  };

  # environment.systemPackages = with pkgs; [ plex ];
}
