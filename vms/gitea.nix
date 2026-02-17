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
    ../modules/services/gitea.nix
    inputs.sops-nix.nixosModules.sops
  ];

  # SOPS configuration for this MicroVM
  # After first boot, get the VM's age key with:
  #   ssh admin@10.100.0.16 "sudo cat /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add it to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];

    # Run sops-install-secrets as a systemd service (after local-fs.target)
    # instead of activation script, since /persist isn't mounted during activation
    useSystemdActivation = true;

    secrets = {
      "gitea/lfs_jwt_secret" = {
        mode = "0440";
        owner = "gitea";
        group = "gitea";
      };
    };
  };

  sys.secrets.giteaLfsJwtSecretFile = config.sops.secrets."gitea/lfs_jwt_secret".path;

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 106;

    mem = 2048;
    vcpu = 2;

    volumes = [
      {
        mountPoint = "/var/lib/gitea";
        image = "gitea-state.img";
        size = 102400;
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
        id = "vm-gitea";
        mac = "02:00:00:00:00:07";
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
    hostName = "gitea-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        11050
        2222
      ];
    };
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.50/24" ];
        Gateway = "10.100.0.1";
        DNS = [ "1.1.1.1" ];
        DHCP = "no";
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
      "d /var/lib/gitea 0700 gitea gitea -"
      "d /var/lib/postgresql 0700 postgres postgres -"
    ];
  };

  sys.services.gitea = {
    enable = true;

    port = 11050;
    openFirewall = true;
    stateDir = "/var/lib/gitea";
    repositoryRoot = "/var/lib/gitea/repositories";

    database = {
      type = "postgres";
      createDatabase = true;
    };

    lfs = {
      enable = true;

      allowPureSSH = true;

      s3Backend = {
        enable = false;

        endpoint = "${config.networking.hostName}.mole-delta.ts.net:${toString config.sys.services.seaweedfs.s3.port}";
        bucket = "gitea-lfs";
        accessKeyFile = config.sys.secrets.seaweedfsAccessKeyFile;
        secretAccessKeyFile = config.sys.secrets.seaweedfsSecretAccessKeyFile;
        serveDirect = false;
      };
    };

    disableRegistration = true;

    reverseProxy.enable = false;

    settings = {
      server = {
        ROOT_URL = "https://git.${VARS.domains.public}/";
        START_SSH_SERVER = true;

        SSH_DOMAIN = "ssh-git.${VARS.domains.public}";
        SSH_LISTEN_HOST = "127.0.0.1";
        SSH_LISTEN_PORT = 2222;
      };

      session.COOKIE_SECURE = true;
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
