# Automatically imported
{ lib, config, ... }:
{
  nix = {
    settings = {
      trusted-users = lib.mkDefault [
        "root"
        "@wheel"
      ];
      experimental-features = lib.mkDefault [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = lib.mkDefault true;
      download-buffer-size = lib.mkDefault 536870912;

      # Hyprland Cachix cache to avoid rebuilding Hyprland and dependencies
      substituters = lib.mkDefault [ "https://hyprland.cachix.org" ];
      trusted-public-keys = lib.mkDefault [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };
    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 7d";
    };
    optimise = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault [ "02:00" ];
    };
    extraOptions = lib.mkDefault "!include ${config.sops.templates."access-tokens".path}";
  };
}
