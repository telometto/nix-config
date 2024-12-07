/**
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

    # 0.2 Networking
    ./networking/defaults.nix
    # ./networking/systemd/systemd-networking.nix # See comment in file
    ./networking/tailscale/tailscale.nix

    # 0.3 System ackages
    ./packages/system-packages.nix

    ### 1. Import common configurations
    ../../common/imports.nix

    # 1.1 Users
    ./home/admin/defaults.nix

    ### 2. Import modules
    # 2.1 Desktop managers
    # ../../modules/desktop-environments/gnome/gnome-settings.nix
    ../../modules/desktop-environments/hyprland/cachix.nix # Hyprland Cachix
    ../../modules/desktop-environments/hyprland/hyprland.nix
    ../../modules/desktop-environments/kde/kde-settings.nix

    # 2.2 Boot/filesystem
    # ../../modules/boot/disko/disko.nix # On hold

    # 2.3 Hardware
    ../../modules/hardware/audio/sound.nix
    ../../modules/hardware/peripherals/razer.nix
    ../../modules/hardware/peripherals/steam-devices.nix
    ../../modules/hardware/printers/printing.nix
    # ../../modules/hardware/peripherals/touchpad.nix
    ../../modules/hardware/video/amdgpu.nix

    # 2.4 Networking
    ../../modules/networking/defaults.nix
    ../../modules/networking/systemd/defaults.nix
    ../../modules/networking/tailscale/defaults.nix
    # ../../modules/networking/vpn/vpn-confinement.nix
    ../../modules/networking/vpn/pvpn-systemd.nix # On hold

    # 2.5 Programs
    ../../modules/programs/steam.nix
    ../../modules/programs/virt-manager.nix

    # 2.6 Security
    ../../modules/security/defaults.nix
    # ../../modules/security/crowdsec/crowdsec.nix
    # ../../modules/security/secrets/agenix.nix
    ../../modules/security/secrets/sops-nix.nix
    ../../modules/security/secureboot/lanzaboote.nix

    # 2.7 Services
    # None for desktop (for now)

    # 2.8 Utilities
    ../../modules/utilities/flatpak.nix

    # 2.9 Virtualization
    ../../modules/virtualization/containers/docker.nix
    ../../modules/virtualization/containers/podman.nix
    ../../modules/virtualization/vm/microvm.nix
    ../../modules/virtualization/vm/vm.nix
  ];

  # Allow unfree packages
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

  system = {
    # copySystemConfiguration = true; # Unsupported with Flakes enabled
    stateVersion = "24.05"; # Did you read the comment?
  };

}
