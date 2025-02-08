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
    distrobox # Distrobox containers
    distrobox-tui # Distrobox terminal UI
    fuse3

    # Wine
    wineWowPackages.stable # Wine compatibility layer
    wineWowPackages.waylandFull # Wine compatibility layer with Wayland support
    winetricks
  ];
}
