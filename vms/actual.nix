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

  microvm = {
    hypervisor = "cloud-hypervisor";

    # CID must be unique per VM (3+ range, 0-2 are reserved)
    vsock.cid = 101; # +1 for each vm

    # 1GiB RAM for Actual Budget
    mem = 1024;
    vcpu = 1;

    # Persistent state volumes
    # NOTE: Actual service uses DynamicUser=true, requiring /var/lib/private/
    volumes = [
      {
        mountPoint = "/var/lib/private/actual";
        image = "actual-state.img";
        size = 2048; # 2GiB for budget data
      }
      {
        mountPoint = "/persist";
        image = "persist.img";
        size = 64; # 64MiB for SSH keys and other persistent state
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
    hostName = "actual-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [ 11051 ];
    };
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.51/24" ];
        Gateway = "10.100.0.1";
        DNS = [ "1.1.1.1" ];
        DHCP = "no";
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
    ];
  };

  # Enable Actual Budget
  sys.services.actual = {
    enable = true;
    port = 11051;
    dataDir = "/var/lib/actual";
  };

  services.openssh.hostKeys = [
    {
      path = "/persist/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/persist/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  # Create admin user for SSH management
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      VARS.users.zeno.sshPubKey
    ];
  };

  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  system.stateVersion = "24.11";
}
