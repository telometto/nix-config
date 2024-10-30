# Server-specific imports
{
  imports = [
    # Boot configuration
    ./boot/filesystem/filesystem.nix

    # Environment configuration
    ./environment/env-vars.nix

    # Networking configuration
    ./networking/systemd/systemd-networking.nix
    ./networking/tailscale/tailscale.nix
    ./networking/vlan/vlans.nix

    # System packages
    ./packages/system-packages.nix

    # Service configuration
    ./services/media/immich.nix
    ./services/media/plex.nix

    # Utilities configuration
    ./services/utilities/cockpit.nix
    ./services/utilities/firefly.nix
    ./services/utilities/printing.nix
    ./services/utilities/sanoid.nix
    ./services/utilities/scrutiny.nix
    ./services/utilities/searx.nix

    # Virtualization configuration
    #./virtualization/containers/docker.nix
    ./virtualization/containers/podman.nix
    ./virtualization/orchestration/k3s.nix
  ];
}