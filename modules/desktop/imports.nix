# Server-specific imports
{
  imports = [
    # Desktop-specific hardware support
    ./hardware/hardware.nix # Enable GPU accel

    # Filesystem configuration
    ./boot/filesystem/filesystem.nix

    # Networking configuration
    ./networking/systemd/systemd-networking.nix
    ./networking/tailscale/tailscale.nix

    # (System) packages
    ./packages/system-packages.nix

    # Programs
    ./programs/steam.nix
    ./programs/virt-manager.nix

    # Utilities configuration
    ./services/utilities/printing.nix
    ./services/utilities/sound.nix
    ./services/utilities/touchpad.nix
    ./services/utilities/usb.nix

    # Virtualization configuration
    #./virtualization/containers/docker.nix
    ./virtualization/containers/podman.nix
  ];
}
