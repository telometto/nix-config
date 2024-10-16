# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  imports = [
    # Include the results of the hardware scan
    ./hardware-configuration.nix

    # Boot configuration
    ../../modules/shared/boot/defaults.nix
    ../../modules/shared/boot/filesystem/defaults.nix
    ../../modules/server/boot/filesystem/filesystem.nix # Server-specific

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
    ../../users/server.nix
  ];

  networking = {
    hostName = myVars.server.hostname;
    hostId = myVars.server.hostId;

    wireless.enable = false;
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  system.stateVersion = "24.05";
}
