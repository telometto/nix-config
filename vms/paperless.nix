{
  config,
  inputs,
  VARS,
  ...
}:
let
  reg = (import ./vm-registry.nix).paperless;
in
{
  imports = [
    ./base.nix
    ../modules/services/paperless.nix
    ../modules/services/protonmail-bridge.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/paperless";
            image = "paperless-state.img";
            size = 307200;
          }
          {
            mountPoint = "/var/lib/postgresql";
            image = "postgresql-state.img";
            size = 30720;
          }
          {
            mountPoint = "/var/lib/protonmail-bridge";
            image = "protonmail-bridge-state.img";
            size = 51200;
          }
        ];
      }
    ))
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

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/paperless 0700 paperless paperless -"
      "d /var/lib/postgresql 0700 postgres postgres -"
      "d /var/lib/protonmail-bridge 0700 protonmail-bridge protonmail-bridge -"
    ];

    services.paperless-scheduler = {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
    };
  };

  sys = {
    services = {
      protonmail-bridge.enable = true;

      nfs = {
        enable = true;

        mounts.paperless-consume = {
          server = "10.100.0.1";
          export = "/rpool/enc/personal/paperless-consumption";
          target = "/var/lib/paperless/consume";
          # nolock avoids NFS lock contention; soft returns errors instead of hanging
          options = [
            "rw"
            "noatime"
            "nofail"
            "nolock"
            "soft"
          ];
        };
      };

      paperless = {
        enable = true;

        database.createLocally = true;
        configureTika = true;

        reverseProxy.enable = false;

        settings = {
          PAPERLESS_URL = "https://docs.${VARS.domains.public}";
          PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://docs.${VARS.domains.public}";
          PAPERLESS_DBHOST = "/run/postgresql";
          PAPERLESS_CONSUMER_RECURSIVE = "true";
          PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = "true";
          # inotify doesn't work over NFS — poll every 30 seconds instead
          # PAPERLESS_CONSUMER_POLLING = "30";
          # Automatically delete duplicate documents from the consumption folder
          PAPERLESS_CONSUMER_DELETE_DUPLICATES = "true";
        };
      };
    };
  };

  # Nginx sits in front of Paperless on the externally-exposed port (11061)
  services.nginx = {
    enable = true;

    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts."paperless" = {
      listen = [
        {
          addr = "0.0.0.0";
          inherit (reg) port;;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:28981";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          client_max_body_size 100M;
        '';
      };
    };
  };
}
