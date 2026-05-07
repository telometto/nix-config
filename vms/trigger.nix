{
  config,
  inputs,
  VARS,
  ...
}:
let
  reg = (import ./vm-registry.nix).trigger;
in
{
  imports = [
    ./base.nix
    ../modules/services/trigger.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/trigger";
            image = "trigger-state.img";
            size = 102400; # 100 GiB — holds Docker images, named volumes, Postgres, ClickHouse, MinIO
          }
        ];
      }
    ))
  ];

  # After first boot, extract this VM's age key and add it to .sops.yaml:
  #   ssh admin@10.100.0.80 "sudo ssh-keygen -y -f /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then re-encrypt nix-secrets.
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets = {
      "trigger/session_secret".mode = "0400";
      "trigger/magic_link_secret".mode = "0400";
      "trigger/encryption_key".mode = "0400";
      "trigger/managed_worker_secret".mode = "0400";
      "trigger/registry_password".mode = "0400";
      "trigger/minio_password".mode = "0400";
      "trigger/postgres_password".mode = "0400";
      "trigger/clickhouse_password".mode = "0400";
      "trigger/whitelisted_emails".mode = "0400";
      "protonmail/smtp_token".mode = "0400";
    };
  };

  sys.services.trigger = {
    enable = true;
    inherit (reg) port;
    appOrigin = "https://triggers.${VARS.domains.public}";

    smtp = {
      enable = true;
      host = "smtp.protonmail.ch";
      port = 587;
      username = "triggers@${VARS.domains.public}";
      fromEmail = "triggers@${VARS.domains.public}";
      passwordFile = config.sops.secrets."protonmail/smtp_token".path;
    };

    auth = {
      whitelistedEmailsFile = config.sops.secrets."trigger/whitelisted_emails".path;
      adminEmailsFile = config.sops.secrets."trigger/whitelisted_emails".path;
    };

    secrets = {
      sessionSecretFile = config.sops.secrets."trigger/session_secret".path;
      magicLinkSecretFile = config.sops.secrets."trigger/magic_link_secret".path;
      encryptionKeyFile = config.sops.secrets."trigger/encryption_key".path;
      managedWorkerSecretFile = config.sops.secrets."trigger/managed_worker_secret".path;
      registryPasswordFile = config.sops.secrets."trigger/registry_password".path;
      minioPasswordFile = config.sops.secrets."trigger/minio_password".path;
      postgresPasswordFile = config.sops.secrets."trigger/postgres_password".path;
      clickhousePasswordFile = config.sops.secrets."trigger/clickhouse_password".path;
    };
  };
}
