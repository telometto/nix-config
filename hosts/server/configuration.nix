# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:
let
  vars = import ../../vars/vars.nix;
in
{
  imports = [
    # Include the results of the hardware scan
    ./hardware-configuration.nix

    # Testing
    #../../modules/networking/systemd/defaults.nix
    ../../modules/services/utilities/searx.nix # Approved
    ../../modules/virtualization/vm/vm.nix

    # Boot configuration
    ../../modules/boot/defaults.nix
    ../../modules/boot/filesystem/defaults.nix

    # Environment configuration
    ../../modules/environment/defaults.nix

    # Locale configuration
    ../../modules/i18n/defaults.nix

    # Network configuration
    ../../modules/networking/defaults.nix
    ../../modules/networking/ssh/ssh.nix
    ../../modules/networking/tailscale/tailscale.nix
    ../../modules/networking/vlan/vlan.nix

    # Nix configuration
    ../../modules/nix/defaults.nix

    # Package configuration
    ../../modules/packages/default-packages.nix

    # Programs configuration
    ../../modules/programs/defaults.nix

    # Security configuration
    ../../modules/security/secrets/agenix.nix
    ../../modules/security/secureboot/lanzaboote.nix
    ../../modules/security/defaults.nix

    # Services configuration
    ../../modules/services/media/plex.nix
    ../../modules/services/utilities/atuin.nix
    ../../modules/services/utilities/cockpit.nix
    ../../modules/services/utilities/printing.nix
    ../../modules/services/utilities/scrutiny.nix

    # Virtualization configuration
    ../../modules/virtualization/containers/podman.nix
    ../../modules/virtualization/orchestration/k3s.nix
    ../../modules/virtualization/vm/microvm.nix

    # User configuration
    ../../users/server.nix
  ];

  networking = {
    hostName = "${vars.hostname}";
    hostId = "${vars.hostId}";

    useNetworkd = true;
    useDHCP = false; # Defaults to true; disabled for systemd-networkd
    networkmanager.enable = false;
    wireless.enable = false;
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  system.stateVersion = "24.05";
}
