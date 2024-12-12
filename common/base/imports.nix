{ ... }:

{
  imports = [
    # Boot
    ./base/boot/defaults.nix

    # Environment
    ./base/environment/defaults.nix

    # Filesystems
    ./base/filesystems/defaults.nix

    # Hardware
    ./base/hardware/firmware/defaults.nix
    ./base/hardware/usb/defaults.nix

    # Localization
    ./base/i18n/defaults.nix

    # Networking
    ./base/networking/ssh/defaults.nix
    ./base/networking/tools/defaults.nix

    # Nix
    ./base/nix/defaults.nix

    # Packages
    ./base/packages/defaults.nix

    # Security
    ./base/security/defaults.nix
    ./base/security/gpg/defaults.nix
    ./base/security/secrets/agenix.nix
    ./base/security/secrets/sops-nix.nix
    ./base/security/secureboot/lanzaboote.nix

    # Utilities
    ./base/utilities/memory/zram.nix
    ./base/utilities/shell/defaults.nix
  ];
}
