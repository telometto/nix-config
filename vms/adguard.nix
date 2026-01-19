{
  lib,
  config,
  pkgs,
  inputs,
  VARS,
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

    # 3GiB RAM - AdGuard Home needs ~350MB+ with filters loaded
    mem = 3072;
    vcpu = 1;

    # Persistent state volume for AdGuard configuration and data
    # Path is relative to host's microvm.stateDir/<vm-name>/
    # Configure stateDir on the HOST via sys.virtualisation.microvm.stateDir
    # NOTE: NixOS adguardhome uses DynamicUser=true, requiring /var/lib/private/
    volumes = [
      {
        mountPoint = "/var/lib/private/AdGuardHome";
        image = "adguard-state.img";
        size = 5120; # 5GiB for logs and config
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
      # DNS and potential future HTTPS/DoH ports
      # Web UI port (11016) is handled by openFirewall = true
      allowedTCPPorts = [
        53 # DNS over TCP
        80 # HTTP (for future use or Cloudflare tunnel)
        443 # HTTPS/DoH (if TLS enabled later)
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
    port = 11016;
    mutableSettings = false; # Use Nix-managed config
    openFirewall = true; # Opens web UI port (11016) in VM firewall

    # Add admin user (password: changeme123 - CHANGE THIS!)
    # Generate new hash: htpasswd -nbB admin "yourpassword" | cut -d: -f2
    settings.users = [
      {
        name = VARS.svc.agh.user;
        password = VARS.svc.agh.password;
      }
    ];

    # Workaround for AdGuard Home v0.107.71 dual-stack DoT bind issue:
    # Use specific VM IP to avoid wildcard dual-stack socket conflicts on port 853 (https://github.com/AdguardTeam/AdGuardHome/discussions/7395).
    # Must use mkForce because module merges settings (concatenates arrays by default).
    settings.dns.bind_hosts = lib.mkForce [ "10.100.0.10" ];
  };

  # Create admin user for SSH management
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      VARS.users.zeno.sshPubKey
    ];
  };

  # Allow wheel group sudo without password inside this MicroVM
  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  system.stateVersion = "24.11";
}
