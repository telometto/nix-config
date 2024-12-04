{ config, lib, pkgs, ... }:

{
  xdg = {
    enable = true;

    cacheHome = "${config.home.homeDirectory}/.cache";
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    stateHome = "${config.home.homeDirectory}/.local/state";

    userDirs = {
      enable = true;

      createDirectories = true; # Default: false
    };
  };

  home.packages = with pkgs; [
    xdg-utils
    xdg-user-dirs
  ];
}
