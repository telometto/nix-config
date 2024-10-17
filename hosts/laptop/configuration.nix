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

    # Desktop Environment
    ../../desktop-environments/gnome/gnome-settings.nix

    # Environment
    ../../modules/shared/environment/defaults.nix

    # Localization
    ../../modules/shared/i18n/defaults.nix

    # Networking
    ../../modules/shared/networking/defaults.nix
    ../../modules/shared/networking/ssh/defaults.nix
    ../../modules/shared/networking/systemd/defaults.nix
    ../../modules/shared/networking/tailscale/defaults.nix
    ../../modules/server/networking/systemd/systemd-networking.nix # Server-specific
    ../../modules/server/networking/tailscale/tailscale.nix # Server-specific
    ../../modules/server/networking/vlan/vlans.nix # Server-specific

    # Packages
    ../../modules/server/packages/system-packages.nix # Server-specific

    # System
    ../../modules/shared/nix/defaults.nix

    # Programs
    ../../modules/shared/programs/defaults.nix

    # Security
    ../../modules/shared/security/defaults.nix
    ../../modules/shared/security/secrets/agenix.nix
    ../../modules/shared/security/secureboot/lanzaboote.nix

    # Services
    ../../modules/shared/services/utilities/atuin.nix
    ../../modules/shared/services/utilities/printing.nix
    ../../modules/server/services/media/plex.nix # Server-specific
    ../../modules/server/services/utilities/cockpit.nix # Server-specific
    #../../modules/server/services/utilities/firefly.nix # Server-specific; not created yet
    ../../modules/server/services/utilities/scrutiny.nix # Server-specific
    ../../modules/server/services/utilities/searx.nix # Server-specific

    # Virtualization
    ../../modules/shared/virtualization/containers/docker.nix
    ../../modules/shared/virtualization/containers/podman.nix
    ../../modules/shared/virtualization/vm/microvm.nix
    ../../modules/shared/virtualization/vm/vm.nix
    ../../modules/server/virtualization/containers/docker.nix # Server-specific
    ../../modules/server/virtualization/containers/podman.nix # Server-specific
    ../../modules/server/virtualization/orchestration/k3s.nix # Server-specific

    # Users
    ../../users/main-user.nix
  ];

  networking = {
    hostName = myVars.laptop.hostname;
    hostId = myVars.laptop.hostId;

    # Pick only one of the below networking options.
    # networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.
    # networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.
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

