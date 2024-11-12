{ ... }:

{
  imports = [
    # Boot
    ./boot/defaults.nix

    # Environment
    ./environment/defaults.nix

    # Hardware
    ./hardware/firmware/defaults.nix
    ./hardware/usb/defaults.nix

    # Localization
    ./i18n/defaults.nix

    # Nix
    ./nix/defaults.nix

    # Packages
    ./packages/defaults.nix

    # Programs
    ./programs/defaults.nix

    # Services

    # Utilities
    ./utilities/memory/zram.nix
    # ./utilities/shell/atuin.nix # Imported in home-manager
  ];
}
