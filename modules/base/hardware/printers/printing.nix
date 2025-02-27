/**
 * This NixOS module configures printing services for a specific host.
 * It enables the printing service by default.
 */

{ config, lib, pkgs, VARS, ... }:

{
  services.printing = {
    enable = true; # Default: false
  };
}
