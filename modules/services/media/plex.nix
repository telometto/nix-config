# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.plex = {
  	enable = true;
  	openFirewall = true;
  	user = "tekkie"; # If not set, the service will run as user "plex"
  	dataDir = "/tank/apps/mediastack/nixos/plex"; # If not set, the service will use the default data directory
  };
}
