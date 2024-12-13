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
    protonvpn-gui # ProtonVPN GUI client
    plex-desktop # Plex media player for desktop
    distrobox # Distrobox containers
    distrobox-tui # Distrobox terminal UI
    fuse3
  ];
}
