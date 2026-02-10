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
    ../modules/services/sabnzbd.nix
  ];

  nixpkgs.config.allowUnfree = true;

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 114;

    mem = 1024;
    vcpu = 1;

    volumes = [
      {
        mountPoint = "/var/lib/sabnzbd";
        image = "sabnzbd-state.img";
        size = 1024;
      }
      {
        mountPoint = "/persist";
        image = "persist.img";
        size = 64;
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = "vm-sabnzbd";
        mac = "02:00:00:00:00:0F";
      }
    ];

    shares = [
      {
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag = "ro-store";
        proto = "virtiofs";
      }
      {
        source = "/rpool/unenc/media/data";
        mountPoint = "/data";
        tag = "media-data";
        proto = "virtiofs";
      }
    ];
  };

  networking = {
    hostName = "sabnzbd-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [ 11050 ];
    };
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.24/24" ];
        Gateway = "10.100.0.26";
        DNS = [ "1.1.1.1" ];
        DHCP = "no";
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
      "d /var/lib/sabnzbd 0700 sabnzbd sabnzbd -"
    ];
  };

  sys.services.sabnzbd = {
    enable = true;
    port = 11050;
    dataDir = "/var/lib/sabnzbd";
    openFirewall = false;
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
