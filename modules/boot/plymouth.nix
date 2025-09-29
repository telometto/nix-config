# Enabled (role)
{ config, lib, ... }:
let
  cfg = config.telometto.boot.plymouth;
in
{
  options.telometto.boot.plymouth.enable =
    lib.mkEnableOption "Enable Plymouth splash screen with silent boot tweaks";

  config = lib.mkIf cfg.enable {
    boot = {
      plymouth = {
        enable = lib.mkDefault true;
        theme = lib.mkDefault "spinner"; # Change to "rings" and enable themePackages below
        # themePackages = with pkgs; [
        #   (adi1090x-plymouth-themes.override { selected_themes = [ "rings" ]; })
        # ];
      };

      # Silent boot parameters
      consoleLogLevel = lib.mkDefault 0;
      initrd.verbose = lib.mkDefault false;
      kernelParams = lib.mkDefault [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
      ];

      loader.timeout = lib.mkDefault 0; # Hide bootloader menu unless a key is pressed
    };
  };
}
