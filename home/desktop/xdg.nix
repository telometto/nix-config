{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.desktop.xdg;
in
{
  options.hm.desktop.xdg = {
    enable = lib.mkEnableOption "XDG directories and desktop integration";

    createDirectories = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create XDG user directories";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg = {
      enable = true;

      cacheHome = "${config.home.homeDirectory}/.cache";
      configHome = "${config.home.homeDirectory}/.config";
      dataHome = "${config.home.homeDirectory}/.local/share";
      stateHome = "${config.home.homeDirectory}/.local/state";

      userDirs = {
        enable = true;
        inherit (cfg) createDirectories;
      };

      autostart = {
        enable = true;
      };

      # mimeApps.enable = true;
    };

    home.packages = [
      pkgs.xdg-utils
      pkgs.xdg-user-dirs
    ];
  };
}
