/*
  This NixOS configuration file defines shared boot configuration defaults.
  It includes settings for the bootloader, supported filesystems, kernel parameters,
  and system services. The configuration is designed to enable features such as
  EFI bootloader support, systemd-boot with a configuration limit, filesystem trimming,
  and Tailscale optimizations. Additionally, it configures Plymouth for a graphical
  boot splash screen and enables "Silent Boot" by minimizing console log output.
  The environment system packages include support for NFS.

  - Bootloader:
  - EFI variables can be modified.
  - systemd-boot is enabled with a configuration limit of 5.
  - Supported filesystems include NFS.
  - fstrim service is enabled for filesystem trimming.
  - Kernel sysctl parameters are set for Cloudflare tunnel and Tailscale optimizations.
  - Plymouth is enabled with the "rings" theme for a graphical boot splash screen.
  - Silent Boot is enabled by setting console log level to 0 and disabling verbose initrd.
  - Kernel parameters are set to minimize log output and enable splash screen.
  - Bootloader timeout is set to 0 to hide the OS choice unless a key is pressed.

  - Environment system packages:
  - Includes libnfs and nfs-utils for NFS support.
*/

{ config, lib, pkgs, myVars, ... }:

{
  # Bootloader
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;

      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
    };

    supportedFilesystems = [ "nfs" ];

    kernel = {
      sysctl = {
        "net.core.wmem_max" = 7500000; # For cloudflared tunnel
        "net.core.rmem_max" = 7500000; # For cloudflared tunnel

        "net.ipv4.ip_forward" = 1; # Tailscale optimization: enable ipv4 forwarding
        "net.ipv6.conf.all.forwarding" = 1; # Tailscale optimization: enable ipv6 forwarding
      };
    };

    plymouth = lib.mkIf (config.networking.hostName != myVars.server.hostname) {
      enable = true;

      theme = "rings";
      themePackages = with pkgs; [
        # By default we would install all themes
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "rings" ];
        })
      ];
    };

    /*
      # Enable "Silent Boot"
      consoleLogLevel = 0;
      initrd.verbose = false;
      kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      ];

      # Hide the OS choice for bootloaders.
      # It's still possible to open the bootloader list by pressing any key
      # It will just not appear on screen unless a key is pressed
      loader.timeout = 0;
      */
  };

  services = {
    fstrim = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    libnfs
    nfs-utils
  ];
}
