/**
 * This NixOS module configures printing services for a specific host.
 * It enables the printing service by default.
 */

{ config, lib, pkgs, ... }:

lib.mkIf (config.networking.hostName != "blizzard")
{
  services.printing = {
    enable = true; # Default: false
  };
}
