/**
 * Host-specific system configuration defaults
 * Edit this configuration file to define what should be installed on
 * your system.  Help is available in the configuration.nix(5) man page
 * and in the NixOS manual (accessible by running ‘nixos-help’).
 */

{ config, lib, inputs, pkgs, ... }:

{
  imports = [
    inputs.vscode-server.nixosModules.default

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
    ../../common/base/imports.nix

    # 1.1 Users
    # 1.1.1 Admin
    ../../common/users/admin/admin.nix

    # 1.1.2 Extra
    # ../../common/users/extra/francesco.nix
    # ../../common/users/extra/gianluca.nix
    # ../../common/users/extra/wife.nix

    ### 2. Import modules
    # 2.1 Desktop managers
    # ../../modules/desktop-environments/gnome/gnome-settings.nix
    # ../../modules/base/desktop-environments/hyprland/cachix.nix # Hyprland Cachix
    # ../../modules/base/desktop-environments/hyprland/hyprland.nix
    ../../modules/base/desktop-environments/kde/kde-settings.nix

    # 2.2 Boot/filesystem
    # ../../modules/boot/base/disko/disko.nix # On hold
    ../../modules/base/boot/plymouth/plymouth.nix

    # 2.3 Hardware
    ../../modules/base/hardware/audio/sound.nix
    ../../modules/base/hardware/peripherals/razer.nix
    ../../modules/base/hardware/peripherals/steam-devices.nix
    ../../modules/base/hardware/printers/printing.nix
    # ../../modules/base/hardware/peripherals/touchpad.nix
    ../../modules/base/hardware/video/amdgpu.nix

    # 2.4 Networking
    ../../modules/base/networking/defaults.nix
    ../../modules/base/networking/systemd/defaults.nix
    ../../modules/base/networking/tailscale/defaults.nix
    # ../../modules/base/networking/vpn/vpn-confinement.nix
    ../../modules/base/networking/vpn/pvpn-systemd.nix # On hold

    # 2.5 Programs
    ../../modules/base/programs/steam.nix
    ../../modules/base/programs/virt-manager.nix
    ../../modules/base/programs/wayland.nix

    # 2.6 Security
    # ../../modules/base/security/crowdsec/crowdsec.nix

    # 2.7 Services
    # ../../modules/base/services/internet/teamviewer.nix

    # 2.8 System
    # ../../modules/base/system/defaults.nix

    # 2.9 Utilities
    ../../modules/base/utilities/flatpak.nix

    # 2.10 Virtualization
    ../../modules/base/virtualization/containers/docker.nix
    ../../modules/base/virtualization/containers/podman.nix
    ../../modules/base/virtualization/vm/microvm.nix
    ../../modules/base/virtualization/vm/vm.nix

    # 3.1 Development
    ../../modules/development/java.nix
  ];

  services.vscode-server.enable = true;

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
