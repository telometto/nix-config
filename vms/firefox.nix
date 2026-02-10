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
    ../modules/services/firefox.nix
    ../modules/virtualisation/virtualisation.nix
  ];

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 115;

    mem = 2048;
    vcpu = 2;

    volumes = [
      {
        mountPoint = "/var/lib/firefox";
        image = "firefox-state.img";
        size = 2048;
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
        id = "vm-firefox";
        mac = "02:00:00:00:00:10";
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

  sys.virtualisation.enable = true;

  networking = {
    hostName = "firefox-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [ 11060 11061 ];
    };
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.25/24" ];
        Gateway = "10.100.0.1";
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

  sys.services.firefox = {
    enable = true;
    dataDir = "/var/lib/firefox";
    httpPort = 11060;
    httpsPort = 11061;
    timeZone = "Europe/Oslo";
    title = "Firefox";
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

  system.stateVersion = "24.11";
}
