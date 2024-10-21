# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, myVars, ... }:

{
  imports = [
    # Include the results of the hardware scan
    ./hardware-configuration.nix

    # Boot configuration
    ../../modules/shared/boot/defaults.nix
    ../../modules/shared/boot/filesystem/defaults.nix

    # Environment
    ../../modules/shared/environment/defaults.nix

    # Hardware
    ../../modules/laptop/hardware/hardware.nix

    # Localization
    ../../modules/shared/i18n/defaults.nix

    # Networking
    ../../modules/shared/networking/defaults.nix
    ../../modules/shared/networking/ssh/defaults.nix
    ../../modules/shared/networking/systemd/defaults.nix
    ../../modules/shared/networking/tailscale/defaults.nix
    ../../modules/laptop/networking/tailscale/tailscale.nix # Laptop-specific

    # Packages
    ../../modules/laptop/packages/system-packages.nix # Laptop-specific

    # System
    ../../modules/shared/nix/defaults.nix

    # Programs
    ../../modules/shared/programs/defaults.nix
    ../../modules/laptop/programs/steam.nix

    # Security
    ../../modules/shared/security/defaults.nix
    ../../modules/shared/security/secrets/agenix.nix
    ../../modules/shared/security/secureboot/lanzaboote.nix

    # Services
    #../../modules/shared/services/utilities/atuin.nix
    ../../modules/shared/services/utilities/flatpak.nix
    ../../modules/shared/services/utilities/fwupd.nix
    ../../modules/laptop/services/utilities/printing.nix # Laptop-specific
    ../../modules/laptop/services/utilities/usb.nix

    # Virtualization
    ../../modules/shared/virtualization/containers/docker.nix
    ../../modules/shared/virtualization/containers/podman.nix
    ../../modules/laptop/virtualization/containers/docker.nix # Laptop-specific
    ../../modules/laptop/virtualization/containers/podman.nix # Laptop-specific

    # Users
    ../../users/main/main-user.nix
    ../../users/extra/extra-users.nix
  ]
  ++ lib.optional myVars.general.enableGnome ../../desktop-environments/gnome/gnome-settings.nix
  ++ lib.optional myVars.general.enableKDE ../../desktop-environments/kde/kde-settings.nix;

  networking = {
    hostName = myVars.laptop.hostname;
    hostId = myVars.laptop.hostId;

    # Pick only one of the below networking options.
    # wireless = { enable = true; }; # Enables wireless support via wpa_supplicant.
    networkmanager = { enable = true; }; # Easiest to use and most distros use this by default.
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}

