# Laptop profile: close to desktop but lighter
{ config, lib, pkgs, VARS, mylib, ... }:
{
  # Hardware defaults
  hardware.steam-hardware.enable = lib.mkDefault true;

  # Display and audio like desktop
  services = {
    xserver.enable = lib.mkDefault false;

    # Audio
    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = lib.mkDefault false;
      alsa = {
        enable = true;
        support32Bit = true;
      };
    };
  };

  # Optional desktop stack left to host (e.g., GNOME on avalanche)

  programs = {
    steam.enable = true; # lighter set than desktop profile in hosts if desired
    gamescope.enable = true;
    gamemode.enable = true;
  };

  # KDE Connect ports handled globally in shared/system.nix; no need to repeat here
}
