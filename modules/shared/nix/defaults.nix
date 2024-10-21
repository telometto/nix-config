# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      download-buffer-size = 536870912;
    };

    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 7d";
    };

    #extraOptions = ''
    #  download-buffer-size = 536870912
    #'';
  };
}
