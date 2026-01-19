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
    ../modules/services/actual.nix
  ];

  networking.hostName = "actual-vm";

  microvm = {
    hypervisor = "cloud-hypervisor";

    # CID must be unique per VM (3+ range, 0-2 are reserved)
    vsock.cid = 101; # +1 for each vm

    # 1GiB RAM for Actual Budget
    mem = 1024;
    vcpu = 1;

    # Persistent state volume for Actual Budget data
    # NOTE: Actual service uses DynamicUser=true, requiring /var/lib/private/
    volumes = [
      {
        mountPoint = "/var/lib/private/actual";
        image = "actual-state.img";
        size = 2048; # 2GiB for budget data
      }
    ];

    # Network interface - connects to host bridge
    interfaces = [
      {
        type = "tap";
        id = "vm-actual";
        mac = "02:00:00:00:00:02"; # +1 for each vm
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
      # Web UI port (3838) will be handled by module's openFirewall option if enabled
      allowedTCPPorts = [
        80 # HTTP (for Cloudflare tunnel or reverse proxy)
        443 # HTTPS (if TLS enabled later)
      ];
    };
  };

  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [ "10.100.0.11/24" ];
      Gateway = "10.100.0.1";
      DNS = [ "1.1.1.1" ];
      DHCP = "no";
    };
  };

  # Enable Actual Budget
  sys.services.actual = {
    enable = true;
    port = 3838;
    dataDir = "/var/lib/actual";
  };

  # Create admin user for SSH management
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      VARS.users.zeno.sshPubKey
    ];
  };

  system.stateVersion = "24.11";
}
