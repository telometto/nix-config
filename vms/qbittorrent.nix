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
    ../modules/services/qbittorrent.nix
  ];

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 113;

    mem = 1024;
    vcpu = 1;

    volumes = [
      {
        mountPoint = "/var/lib/qbittorrent";
        image = "qbittorrent-state.img";
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
        id = "vm-qbittorrent";
        mac = "02:00:00:00:00:0E";
      }
    ];

    shares = [
      {
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag = "ro-store";
        proto = "virtiofs";
      }
    ];
  };

  networking = {
    hostName = "qbittorrent-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        11051
        50820
      ];
      allowedUDPPorts = [ 50820 ];
    };
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.23/24" ];
        Gateway = "10.100.0.26";
        DNS = [ "1.1.1.1" ];
        DHCP = "no";
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
      "d /data 0750 root root -"
    ];
  };

  sys.services.nfs = {
    enable = true;

    mounts.media = {
      server = "10.100.0.1";
      export = "/rpool/unenc/media/data";
      target = "/data";
    };
  };

  sys.services.qbittorrent = {
    enable = true;
    webPort = 11051;
    torrentPort = 50820;
    dataDir = "/var/lib/qbittorrent";
    openFirewall = false;

    alternativeWebUI = {
      enable = true;
      package = pkgs.vuetorrent;
    };
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
