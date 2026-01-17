{
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./base.nix
    ../modules/services/adguardhome.nix
    ../modules/services/resolved.nix
  ];

  networking.hostName = "adguard-vm";

  # MicroVM-specific configuration
  microvm = {
    hypervisor = "cloud-hypervisor";

    # Enable vsock for systemd-notify (required by cloud-hypervisor)
    # CID must be unique per VM (3+ range, 0-2 are reserved)
    vsock.cid = 100;

    # 512MB RAM is sufficient for AdGuard Home
    mem = 512;
    vcpu = 1;

    # Persistent state volume for AdGuard configuration and data
    # Path is relative to host's microvm.stateDir/<vm-name>/
    # Configure stateDir on the HOST via sys.virtualisation.microvm.stateDir
    volumes = [
      {
        mountPoint = "/var/lib/AdGuardHome";
        image = "adguard-state.img";
        size = 1024; # 1GB for logs and config
      }
    ];

    # Network interface - connects to host bridge
    interfaces = [
      {
        type = "tap";
        id = "vm-adguard";
        mac = "02:00:00:00:00:01";
      }
    ];

    # Share host's nix store (read-only) for smaller image size
    shares = [
      {
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag = "ro-store";
        proto = "virtiofs";
      }
    ];
  };

  # Static IP on the MicroVM network (using systemd-networkd)
  networking = {
    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        53 # DNS
        80 # AdGuard web UI
        443 # HTTPS
        11016 # Initial setup
      ];
      allowedUDPPorts = [
        53 # DNS
      ];
    };
  };

  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [ "10.100.0.10/24" ];
      Gateway = "10.100.0.1";
      DNS = [ "1.1.1.1" ];
      DHCP = "no";
    };
  };

  # Enable AdGuard Home
  sys.services.adguardhome = {
    enable = true;
    openFirewall = false; # Handled above
  };

  # Create admin user for SSH management
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here or use sops
    ];
  };

  system.stateVersion = "24.11";
}
