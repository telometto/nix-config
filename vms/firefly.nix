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
    ../modules/services/firefly.nix
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets = {
      "firefly/app_key" = {
        mode = "0440";
        owner = "firefly-iii";
        group = "firefly-iii";
      };
    };
  };

  sys.secrets.fireflyAppKeyFile = config.sops.secrets."firefly/app_key".path;

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 121;

    mem = 2048;
    vcpu = 2;

    volumes = [
      {
        mountPoint = "/var/lib/firefly-iii";
        image = "firefly-iii-state.img";
        size = 10240;
      }
      {
        mountPoint = "/var/lib/postgresql";
        image = "postgresql-state.img";
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
        id = "vm-firefly";
        mac = "02:00:00:00:00:16";
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
    hostName = "firefly-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [ 11062 ];
    };
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.62/24" ];
        Gateway = "10.100.0.1";
        DNS = [ "1.1.1.1" ];
        DHCP = "no";
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
      "d /var/lib/firefly-iii 0700 firefly-iii firefly-iii -"
      "d /var/lib/postgresql 0700 postgres postgres -"
    ];
  };

  sys.services.firefly = {
    enable = true;

    reverseProxy.enable = false;

    settings = {
      ALLOW_WEBHOOKS = false;
      COOKIE_SECURE = "true";
      SEND_REGISTRATION_MAIL = true;
      SEND_LOGIN_NEW_IP_WARNING = true;
    };
  };

  # Outer Nginx listens on 11062 and proxies to Firefly's PHP-FPM Nginx on :80
  services.nginx.virtualHosts."firefly".listen = lib.mkForce [
    {
      addr = "0.0.0.0";
      port = 11062;
    }
  ];

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
