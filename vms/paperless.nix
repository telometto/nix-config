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
    ../modules/services/paperless.nix
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets = {
      "paperless/admin_password" = {
        mode = "0440";
        owner = "paperless";
        group = "paperless";
      };
      "paperless/secret_key" = {
        mode = "0440";
        owner = "paperless";
        group = "paperless";
      };
    };
  };

  sys.secrets = {
    paperlessKeyFile = config.sops.secrets."paperless/admin_password".path;
    paperlessSecretKeyFile = config.sops.secrets."paperless/secret_key".path;
  };

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 120;

    mem = 4096;
    vcpu = 4;

    volumes = [
      {
        mountPoint = "/var/lib/paperless";
        image = "paperless-state.img";
        size = 20480;
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
        id = "vm-paperles";
        mac = "02:00:00:00:00:15";
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
        source = "/rpool/enc/personal/documents";
        mountPoint = "/var/lib/paperless/consume";
        tag = "paperless-consume";
        proto = "virtiofs";
      }
    ];
  };

  networking = {
    hostName = "paperless-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [ 11061 ];
    };
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.61/24" ];
        Gateway = "10.100.0.1";
        DNS = [ "1.1.1.1" ];
        DHCP = "no";
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
      "d /var/lib/paperless 0700 paperless paperless -"
      "d /var/lib/postgresql 0700 postgres postgres -"
    ];

    services.paperless-scheduler = {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
    };
  };

  sys.services.paperless = {
    enable = true;

    database.createLocally = true;
    configureTika = true;

    reverseProxy.enable = false;

    settings = {
      PAPERLESS_DBHOST = "/run/postgresql";
      PAPERLESS_CONSUMER_RECURSIVE = "true";
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = "true";
    };
  };

  # Nginx sits in front of Paperless on the externally-exposed port (11061)
  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts."paperless" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 11061;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:28981";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Forwarded-Proto $scheme;
          client_max_body_size 100M;
        '';
      };
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

  system.stateVersion = "24.11";
}
