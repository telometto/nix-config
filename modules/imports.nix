/**
 * This NixOS module configuration file specifies a list of imports for various
 * system configurations and services. The imports are organized into categories
 * such as filesystem, hardware, networking, security, services, and virtualization.
 * 
 * The `imports` attribute is a list of paths to other Nix files that contain
 * specific configurations. These configurations are modularized to keep the
 * system configuration organized and maintainable.
 * 
 * Additionally, there is a conditional import section that includes certain
 * program and utility configurations only if the host is not my server.
 * This allows for hostname-specific customizations.
 */

{ config, lib, myVars, ... }:

{
  imports = [
    # Filesystem imports
    #./boot/disko/disko.nix

    # Hardware imports
    ./hardware/audio/sound.nix
    ./hardware/peripherals/razer.nix
    ./hardware/peripherals/steam-devices.nix
    ./hardware/printers/printing.nix
    ./hardware/peripherals/touchpad.nix
    ./hardware/video/amdgpu.nix

    # Networking imports
    ./networking/defaults.nix
    ./networking/ssh/defaults.nix
    ./networking/systemd/defaults.nix
    ./networking/tailscale/defaults.nix

    # Program imports
    ./programs/steam.nix # ok
    ./programs/virt-manager.nix #ok

    # Security imports
    ./security/defaults.nix
    #./security/crowdsec/crowdsec.nix
    #./security/secrets/agenix.nix
    ./security/secrets/sops-nix.nix
    ./security/secureboot/lanzaboote.nix

    # Service imports

    # Utility imports
    ./utilities/flatpak.nix

    # Virtualization imports
    ./virtualization/containers/docker.nix
    ./virtualization/containers/podman.nix
    ./virtualization/vm/microvm.nix
    ./virtualization/vm/vm.nix
  ];
}
