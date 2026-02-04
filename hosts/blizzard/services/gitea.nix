{ config, VARS, ... }:
{
  sys.services.gitea = {
    enable = false;

    port = 11015;
    openFirewall = true;

    stateDir = "/rpool/unenc/apps/nixos/gitea";
    repositoryRoot = "/rpool/unenc/apps/nixos/gitea/repositories";

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

    settings.server = {
      START_SSH_SERVER = true;

      SSH_DOMAIN = "ssh-git.${VARS.domains.public}";
      SSH_LISTEN_HOST = "127.0.0.1";
      SSH_LISTEN_PORT = 2222;

      PUBLIC_URL_DETECTION = "auto";
    };

    reverseProxy = {
      enable = true;
      domain = "git.${VARS.domains.public}";
      cfTunnel.enable = true;
    };
  };
}
