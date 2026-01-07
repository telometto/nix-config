# Enabled (role)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sys.boot.plymouth;
in
{
  options.sys.boot.plymouth = {
    enable = lib.mkEnableOption "Enable Plymouth splash screen with silent boot tweaks";

    theme = lib.mkOption {
      type = lib.types.str;
      default = "spinner";
      description = "Plymouth theme to use";
    };

    themePackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Plymouth theme packages to install";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      plymouth = {
        enable = lib.mkDefault true;
        inherit (cfg) theme themePackages;
      };

      consoleLogLevel = lib.mkDefault 3;
      initrd.verbose = lib.mkDefault false;
      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "udev.log_level=3"
        "rd.systemd.show_status=auto"
        # "udev.log_priority=3"
      ];

      loader.timeout = lib.mkDefault 0;
    };
  };
}
