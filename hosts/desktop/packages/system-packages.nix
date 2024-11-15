/**
 * 
 * This Nix expression defines host-specific system configuration defaults for a desktop environment.
 * It specifies the system packages to be included in the environment.
 * 
 * The `environment.systemPackages` attribute is used to list the packages that should be available
 * in the system environment.
 */

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # System utilities
    microcode-amd # AMD CPU microcode updates
    yaru-theme # Yaru theme for Ubuntu

    # System tools
    deja-dup # Backup tool
    restic # Enables restic in deja-dup
    vorta # Backup software
  ];
}
