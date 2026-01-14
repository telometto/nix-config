{ lib, config, ... }:
let
  cfg = config.sys.services.gitea;
in
{
  options.sys.services.gitea = {
    enable = lib.mkEnableOption "Gitea";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/gitea";
    };

    repositoryRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to git repositories. Defaults to stateDir/repositories.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [
          "sqlite3"
          "mysql"
          "postgres"
        ];
        default = "postgres";
      };

      createDatabase = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };

    lfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      allowPureSSH = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Allow LFS transfers over pure SSH. Disable this to force HTTP-based LFS,
          which is useful when SSH goes through a tunnel with size limits (e.g., Cloudflare).
        '';
      };

      s3Backend = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use S3-compatible backend (e.g., SeaweedFS) instead of local storage";
        };

        endpoint = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "blizzard.mole-delta.ts.net:8333";
          description = ''
            S3 endpoint hostname:port (required if s3Backend.enable is true).
            Format: hostname:port (WITHOUT http:// prefix)
            Examples:
              - "127.0.0.1:8333" for local-only access
              - "blizzard.mole-delta.ts.net:8333" for Tailscale access
          '';
        };

        bucket = lib.mkOption {
          type = lib.types.str;
          default = "gitea";
          description = "S3 bucket name for LFS storage";
        };

        accessKeyId = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "S3 access key (can use secrets via sops)";
        };

        secretAccessKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "S3 secret access key (can use secrets via sops)";
        };

        useSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use HTTPS for S3 connection";
        };
      };

    };

    disableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "git.example.com";
      };

      cfTunnel.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Gitea settings (see https://docs.gitea.io/en-us/config-cheat-sheet/).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.gitea = {
      enable = true;
      inherit (cfg) stateDir;
      repositoryRoot = lib.mkIf (cfg.repositoryRoot != null) cfg.repositoryRoot;

      database = {
        inherit (cfg.database) type createDatabase;
      };

      lfs.enable = cfg.lfs.enable;

      settings = lib.mkMerge [
        {
          server = {
            HTTP_PORT = cfg.port;
            ROOT_URL = lib.mkIf (
              cfg.reverseProxy.enable && cfg.reverseProxy.domain != null
            ) "https://${cfg.reverseProxy.domain}/";

            LFS_START_SERVER = lib.mkIf cfg.lfs.enable true;
            LFS_ALLOW_PURE_SSH = lib.mkIf cfg.lfs.enable cfg.lfs.allowPureSSH;
            LFS_HTTP_AUTH_EXPIRY = lib.mkIf cfg.lfs.enable "24h";
          };

          service.DISABLE_REGISTRATION = cfg.disableRegistration;

          session.COOKIE_SECURE = lib.mkIf cfg.reverseProxy.enable true;
        }
        (lib.mkIf (cfg.lfs.enable && cfg.lfs.s3Backend.enable) {
          lfs = {
            STORAGE_TYPE = "minio";
            MINIO_ENDPOINT = cfg.lfs.s3Backend.endpoint;
            MINIO_ACCESS_KEY_ID = lib.mkIf (
              cfg.lfs.s3Backend.accessKeyId != null
            ) cfg.lfs.s3Backend.accessKeyId;
            MINIO_SECRET_ACCESS_KEY = lib.mkIf (
              cfg.lfs.s3Backend.secretAccessKey != null
            ) cfg.lfs.s3Backend.secretAccessKey;
            MINIO_BUCKET = cfg.lfs.s3Backend.bucket;
            MINIO_USE_SSL = cfg.lfs.s3Backend.useSSL;
          };
        })
        cfg.settings
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    services.traefik.dynamicConfigOptions =
      lib.mkIf (cfg.reverseProxy.enable && config.services.traefik.enable or false)
        {
          http = {
            routers.gitea = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "gitea";
              entryPoints = [ "web" ];
              middlewares = [
                "security-headers"
                "gitea-xfp-https"
              ];
            };

            services.gitea.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
            };

            middlewares."gitea-xfp-https".headers.customRequestHeaders = {
              "X-Forwarded-Proto" = "https";
            };
          };
        };

    sys.services.cloudflared.ingress =
      lib.mkIf
        (
          cfg.reverseProxy.cfTunnel.enable
          && cfg.reverseProxy.enable
          && config.sys.services.cloudflared.enable or false
        )
        {
          "${cfg.reverseProxy.domain}" = "http://localhost:80";
        };

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.gitea.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.gitea.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.gitea.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.lfs.s3Backend.enable || cfg.lfs.s3Backend.endpoint != null;
        message = "sys.services.gitea.lfs.s3Backend.endpoint must be set when s3Backend.enable is true";
      }
      {
        assertion = !cfg.lfs.s3Backend.enable || cfg.lfs.enable;
        message = "sys.services.gitea.lfs.enable must be true when s3Backend.enable is true";
      }
    ];

    warnings = lib.optional (cfg.lfs.s3Backend.enable) ''
      Gitea LFS S3 backend is enabled. LFS storage is now on SeaweedFS at ${cfg.lfs.s3Backend.endpoint}
      bucket: ${cfg.lfs.s3Backend.bucket}
    '';
  };
}
