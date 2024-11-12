/**
 * This NixOS module configures printing services for a specific host.
 * It enables the printing service by default.
 */

{ config, lib, pkgs, myVars, ... }:

lib.mkIf (config.networking.hostName != myVars.server.hostname)
{
  services.printing = {
    enable = true; # Default: false
  };
}
