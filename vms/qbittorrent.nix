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
        size = 10240;
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
      {
        source = "/rpool/unenc/media/data";
        mountPoint = "/data";
        tag = "media-data";
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
        11030
        50820
      ];
      allowedUDPPorts = [ 50820 ];
    };
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.30/24" ];
        Gateway = "10.100.0.11";
        DNS = [ "1.1.1.1" ];
        DHCP = "no";
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
      "d /var/lib/qbittorrent 0700 qbittorrent qbittorrent -"
    ];
  };

  sys.services.qbittorrent = {
    enable = true;
    webPort = 11030;
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

  security.sudo.wheelNeedsPassword = lib.mkForce false;

  system.stateVersion = "24.11";
}
