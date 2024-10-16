# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  services.plex = {
    enable = true;
    openFirewall = true;
    user = myVars.server.user; # If not set, the service will run as user "plex"
    dataDir = myVars.server.plexDataDir; # If not set, the service will use the default data directory
  };
}
