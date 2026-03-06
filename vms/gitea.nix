{
  config,
  inputs,
  VARS,
  consts,
  ...
}:
let
  reg = (import ./vm-registry.nix).gitea;
in
{
  imports = [
    ./base.nix
    ../modules/services/gitea.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
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
        ];
      }
    ))
  ];

  # SOPS configuration for this MicroVM
  # After first boot, get the VM's age key with:
  #   ssh admin@10.100.0.50 "sudo cat /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add it to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
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

  networking.firewall.allowedTCPPorts = [
    reg.port
    2222
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/gitea 0700 gitea gitea -"
    "d /var/lib/postgresql 0700 postgres postgres -"
  ];

  sys.services.gitea = {
    enable = true;

    port = reg.port;
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

        endpoint = "${config.networking.hostName}.${consts.tailscale.suffix}:${toString config.sys.services.seaweedfs.s3.port}";
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
        SSH_LISTEN_HOST = "0.0.0.0";
        SSH_LISTEN_PORT = 2222;
      };

      session.COOKIE_SECURE = true;
    };
  };
}
