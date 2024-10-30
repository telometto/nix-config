# Default imports for all devices
{
  imports = [
    # Boot defaults
    ./boot/defaults.nix
    ./boot/filesystem/defaults.nix

    # Env defaults
    ./environment/defaults.nix

    # Locale defaults
    ./i18n/defaults.nix

    # Networking defaults
    ./networking/defaults.nix
    ./networking/ssh/defaults.nix
    ./networking/systemd/defaults.nix
    ./networking/tailscale/defaults.nix

    # Nix defaults
    ./nix/defaults.nix

    # Program defaults
    ./programs/defaults.nix

    # Security defaults
    ./security/defaults.nix
    ./security/secrets/agenix.nix
    ./security/secureboot/lanzaboote.nix

    # Services defaults
    ./services/utilities/atuin.nix
    ./services/utilities/flatpak.nix
    ./services/utilities/fwupd.nix

    # Virtualization defaults
    #./virtualization/containers/docker.nix
    ./virtualization/containers/podman.nix
    ./virtualization/vm/microvm.nix
    ./virtualization/vm/vm.nix
  ];
}