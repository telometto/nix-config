{ ... }:

{
  imports = [
    # Boot
    ./boot/defaults.nix

    # Environment
    ./environment/defaults.nix

    # Filesystems
    ./filesystems/defaults.nix

    # Hardware
    ./hardware/firmware/defaults.nix
    ./hardware/usb/defaults.nix

    # Localization
    ./i18n/defaults.nix

    # Networking
    ./networking/ssh/defaults.nix
    ./networking/tools/defaults.nix

    # Nix
    ./nix/defaults.nix

    # Packages
    ./packages/defaults.nix

    # Security
    ./security/defaults.nix
    ./security/gpg/defaults.nix
    # ./security/secrets/agenix.nix
    ./security/secrets/sops-nix.nix
    ./security/secureboot/lanzaboote.nix

    # Utilities
    ./utilities/memory/zram.nix
    ./utilities/shell/defaults.nix
  ];
}
