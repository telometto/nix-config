{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.desktop.xdg;
  userHome = config.home.homeDirectory;
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
      enable = lib.mkDefault true;

      cacheHome = lib.mkDefault "${userHome}/.cache";
      configHome = lib.mkDefault "${userHome}/.config";
      dataHome = lib.mkDefault "${userHome}/.local/share";
      stateHome = lib.mkDefault "${userHome}/.local/state";

      userDirs = {
        enable = lib.mkDefault true;
        inherit (cfg) createDirectories;
      };

      autostart = {
        enable = lib.mkDefault true;
      };

      # mimeApps.enable = true;
    };

    home.packages = [
      pkgs.xdg-utils
      pkgs.xdg-user-dirs
    ];
  };
}
