# Enabled (role)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.telometto.boot.plymouth;
in
{
  options.telometto.boot.plymouth = {
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

      # Silent boot parameters
      consoleLogLevel = lib.mkDefault 3;
      initrd.verbose = lib.mkDefault false;
      kernelParams = lib.mkDefault [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "udev.log_level=3"
        "rd.systemd.show_status=auto"
        # "udev.log_priority=3"
      ];

      loader.timeout = lib.mkDefault 0; # Hide bootloader menu unless a key is pressed
    };
  };
}
