# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.plex = {
    enable = true;
    openFirewall = true;
    user = config.sops.secrets.serverAdminUser.path; # If not set, the service will run as user "plex"
    dataDir = config.sops.secrets.plexDataDir.path; # If not set, the service will use the default data directory
  };

  environment.systemPackages = with pkgs; [ plex ];
}
