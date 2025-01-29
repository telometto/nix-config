/*
 * Host-specific system configuration defaults
 * Edit this configuration file to define what should be installed on
 * your system.  Help is available in the configuration.nix(5) man page
 * and in the NixOS manual (accessible by running ‘nixos-help’).
*/

{ config, lib, pkgs, ... }:

{
  imports = [
    ### 0. Desktop-specific settings
    # 0.0 Include the results of the hardware scan
    ./hardware-configuration.nix # DO NOT TOUCH

    # 0.1 Boot
    ./boot/defaults.nix

    # 0.2 Environment
    ./environment/defaults.nix

    # 0.3 Networking
    ./networking/defaults.nix
    ./networking/tailscale/tailscale.nix

    # 0.4 System packages
    ./packages/defaults.nix

    # 0.5 Utilities
    #./utilities/filesystem/filebrowser.nix
    # ./utilities/filesystem/sanoid.nix
    ./utilities/filesystem/scrutiny.nix
    ./utilities/monitoring/cockpit.nix

    # 0.6 Virtualization
    ./virtualization/orchestration/k3s.nix

    ### 1. Import common configurations
    ../../common/base/imports.nix

    # 1.1 Users
    ../../common/users/admin/admin.nix

    ### 2. Import modules
    # 2.1 Desktop managers
    # ../../modules/base/base/desktop-environments/kde/kde-settings.nix
    # ../../modules/base/base/desktop-environments/gnome/gnome-settings.nix

    # 2.2 Boot/filesystem
    # ../../modules/base/base/boot/disko/disko.nix # On hold

    # 2.3 Hardware
    # ../../modules/base/hardware/audio/sound.nix
    # ../../modules/base/hardware/peripherals/razer.nix
    # ../../modules/base/hardware/peripherals/steam-devices.nix
    # ../../modules/base/hardware/printers/printing.nix
    # ../../modules/base/hardware/peripherals/touchpad.nix
    # ../../modules/base/hardware/video/amdgpu.nix

    # 2.4 Networking
    ../../modules/base/networking/defaults.nix
    ../../modules/base/networking/systemd/defaults.nix
    ../../modules/base/networking/tailscale/defaults.nix
    # ../../modules/base/networking/vpn/vpn-confinement.nix

    # 2.5 Programs
    # ../../modules/base/programs/steam.nix
    # ../../modules/base/programs/virt-manager.nix

    # 2.6 Security
    # ../../modules/base/security/crowdsec/crowdsec.nix

    # 2.7 Services
    ../../modules/base/services/backups/borg.nix
    # ../../modules/base/services/documents/paperless.nix
    # ../../modules/base/services/finance/firefly.nix # Not yet created
    # ../../modules/base/services/internet/searx.nix
    # ../../modules/base/services/media/immich.nix
    # ../../modules/base/services/media/jellyfin.nix
    # ../../modules/base/services/media/nixarr.nix # Not in use; using k3s
    # ../../modules/base/services/media/ombi.nix
    # ../../modules/base/services/media/tautulli.nix
    ../../modules/base/services/media/plex.nix
    # ../../modules/base/services/monitoring/prometheus.nix # On hold

    # 2.8 System
    ../../modules/base/system/defaults.nix

    # 2.9 Utilities
    # ../../modules/base/utilities/flatpak.nix

    # 2.10 Virtualization
    ../../modules/base/virtualization/containers/docker.nix
    ../../modules/base/virtualization/containers/podman.nix
    ../../modules/base/virtualization/vm/microvm.nix
    ../../modules/base/virtualization/vm/vm.nix
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  /*
  * Some programs need SUID wrappers, can be configured further or are
  * started in user sessions.
  * programs.mtr.enable = true;
  *
  * Copy the NixOS configuration file and link it from the resulting system
  * (/run/current-system/configuration.nix). This is useful in case you
  * accidentally delete configuration.nix.
  * system.copySystemConfiguration = true;
  *
  * This option defines the first version of NixOS you have installed on this particular machine,
  * and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  *
  * Most users should NEVER change this value after the initial install, for any reason,
  * even if you've upgraded your system to a new NixOS release.
  *
  * This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  * so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  * to actually do that.
  *
  * This value being lower than the current NixOS release does NOT mean your system is
  * out of date, out of support, or vulnerable.
  *
  * Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  * and migrated your data accordingly.
  *
  * For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
  */
  system.stateVersion = "24.11"; # Did you read the comment?

}
