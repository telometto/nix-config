{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.matrix-authentication-service;
  traefikLib = import ../../lib/traefik.nix { inherit lib; };

  # Base config without secrets — an external oneshot (e.g. the VM's
  # mas-secret service) must merge decrypted secrets and point
  # runtimeConfigFile at the result.
  baseConfig = lib.recursiveUpdate {
    http = {
      listeners = [
        {
          name = "web";
          resources = [
            { name = "discovery"; }
            { name = "human"; }
            { name = "oauth"; }
            { name = "compat"; }
            { name = "graphql"; }
            { name = "assets"; }
          ];
          binds = [
            {
              address = "${if cfg.openFirewall then "0.0.0.0" else "127.0.0.1"}:${toString cfg.port}";
            }
          ];
          proxy_protocol = false;
        }
        {
          name = "internal";
          resources = [ { name = "health"; } ];
          binds = [
            {
              host = "localhost";
              port = cfg.healthPort;
            }
          ];
          proxy_protocol = false;
        }
      ];
      trusted_proxies = [
        "127.0.0.1/8"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
      ];
      public_base = cfg.publicBaseUrl;
      inherit (cfg) issuer;
    };

    database = {
      inherit (cfg.database) uri;
      max_connections = 10;
      min_connections = 0;
      connect_timeout = 30;
      idle_timeout = 600;
      max_lifetime = 1800;
    };

    email = {
      inherit (cfg.email) from transport;
      reply_to = cfg.email.replyTo;
    }
    // lib.optionalAttrs (cfg.email.transport == "smtp") {
      inherit (cfg.email) mode hostname username;
      port = cfg.email.smtpPort;
      # password injected at runtime via runtimeConfigFile
    };

    passwords = {
      inherit (cfg.passwords) enabled;
      schemes = [
        {
          version = 1;
          algorithm = "argon2id";
        }
      ];
      minimum_complexity = cfg.passwords.minimumComplexity;
    };

    matrix = {
      kind = "synapse";
      inherit (cfg.matrix) homeserver endpoint;
      # secret injected at runtime via runtimeConfigFile
    };

    # secrets and clients are injected at runtime via runtimeConfigFile
  } cfg.settings;

  baseConfigFile = pkgs.writeText "mas-config-base.json" (builtins.toJSON baseConfig);

  postgresqlPackage = config.services.postgresql.package;
in
{
  options.sys.services.matrix-authentication-service = {
    enable = lib.mkEnableOption "Matrix Authentication Service (MAS)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Port for the MAS web listener (OIDC, compat, UI).";
    };

    healthPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Port for the MAS internal health-check listener.";
    };

    publicBaseUrl = lib.mkOption {
      type = lib.types.str;
      description = "Public-facing base URL of MAS.";
      example = "https://matrix.example.com/";
    };

    issuer = lib.mkOption {
      type = lib.types.str;
      description = "OIDC issuer URL advertised in discovery documents.";
      example = "https://matrix.example.com/";
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Create a local PostgreSQL database for MAS.";
      };

      uri = lib.mkOption {
        type = lib.types.str;
        default = "postgresql:///mas?host=/run/postgresql";
        description = "PostgreSQL connection URI.";
      };
    };

    email = {
      from = lib.mkOption {
        type = lib.types.str;
        description = "Sender address for MAS emails.";
        example = ''"Matrix Auth" <auth@example.com>'';
      };

      replyTo = lib.mkOption {
        type = lib.types.str;
        description = "Reply-to address for MAS emails.";
        example = ''"Matrix Auth" <auth@example.com>'';
      };

      transport = lib.mkOption {
        type = lib.types.enum [
          "blackhole"
          "smtp"
        ];
        default = "smtp";
        description = "Email transport — blackhole discards all mail.";
      };

      mode = lib.mkOption {
        type = lib.types.enum [
          "plain"
          "starttls"
          "tls"
        ];
        default = "starttls";
        description = "SMTP connection security mode.";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SMTP server hostname.";
      };

      smtpPort = lib.mkOption {
        type = lib.types.port;
        default = 587;
        description = "SMTP server port.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SMTP authentication username.";
      };
    };

    passwords = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable password-based authentication.";
      };

      minimumComplexity = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Minimum password complexity score (0–4, zxcvbn scale).";
      };
    };

    matrix = {
      homeserver = lib.mkOption {
        type = lib.types.str;
        default = "localhost:8008";
        description = "Synapse server_name:port for MAS to contact.";
      };

      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:8008/";
        description = "Synapse admin API endpoint URL.";
      };
    };

    clientId = lib.mkOption {
      type = lib.types.str;
      default = "0000000000000000000SYNAPSE";
      description = "OIDC client ID that Synapse uses to authenticate against MAS.";
    };

    runtimeConfigFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override the MAS config file path at runtime. When null, uses the Nix-generated base config.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions {
      name = "matrix-authentication-service";
      defaults.enable = false;
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional MAS settings merged into the base configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.mas = {
      isSystemUser = true;
      group = "mas";
      home = "/var/lib/mas";
      description = "Matrix Authentication Service";
    };
    users.groups.mas = { };

    # Base config (without secrets) — written to /etc so the runtime
    # assembly service can read and merge it with decrypted secrets.
    environment.etc."matrix-authentication-service/config.json" = {
      source = baseConfigFile;
      user = "mas";
      group = "mas";
      mode = "0400";
    };

    # Idempotent DB creation — runs before MAS to ensure the role and
    # database exist even if PostgreSQL was initialised before MAS was added.
    systemd.services.mas-db-init = lib.mkIf cfg.database.createLocally {
      description = "Create MAS PostgreSQL database and role";
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      before = [ "matrix-authentication-service.service" ];
      requiredBy = [ "matrix-authentication-service.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.services.postgresql.superUser;
      };
      script = ''
        set -euo pipefail
        ${postgresqlPackage}/bin/psql -tc \
          "SELECT 1 FROM pg_roles WHERE rolname='mas'" | grep -q 1 || \
          ${postgresqlPackage}/bin/psql -c "CREATE ROLE mas WITH LOGIN"
        ${postgresqlPackage}/bin/psql -tc \
          "SELECT 1 FROM pg_database WHERE datname='mas'" | grep -q 1 || \
          ${postgresqlPackage}/bin/psql -c \
            "CREATE DATABASE mas WITH OWNER mas TEMPLATE template0 LC_COLLATE = 'C' LC_CTYPE = 'C'"
      '';
    };

    services.postgresql = lib.mkIf cfg.database.createLocally {
      enable = true;
    };

    systemd.services.matrix-authentication-service = {
      description = "Matrix Authentication Service";
      after =
        (if cfg.database.createLocally then [ "postgresql.service" ] else [ "network-online.target" ])
        ++ [ "network.target" ];
      requires = lib.optionals cfg.database.createLocally [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "mas";
        Group = "mas";
        ExecStart =
          let
            configPath = if cfg.runtimeConfigFile != null then cfg.runtimeConfigFile else "${baseConfigFile}";
          in
          "${pkgs.matrix-authentication-service}/bin/mas-cli server --config ${configPath}";
        Restart = "on-failure";
        RestartSec = "5s";

        StateDirectory = "mas";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "mas";
        RuntimeDirectoryMode = "0750";

        # Hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ "/var/lib/mas" ];
      };
    };

    services.traefik.dynamic.files.matrix-authentication-service = traefikLib.mkTraefikDynamicConfig {
      name = "matrix-authentication-service";
      inherit cfg config;
      inherit (cfg) port;
      defaultMiddlewares = [ "security-headers" ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.matrix-authentication-service.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.matrix-authentication-service.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      {
        assertion =
          !(
            builtins.match ".*[:@].*@.*" cfg.database.uri != null
            || builtins.match ".*password=.*" cfg.database.uri != null
          );
        message = "sys.services.matrix-authentication-service.database.uri must not contain embedded credentials — inject them via runtime secrets instead";
      }
      {
        assertion = cfg.email.transport != "smtp" || (cfg.email.hostname != "" && cfg.email.username != "");
        message = "sys.services.matrix-authentication-service.email.hostname and email.username must be set when email.transport is 'smtp'";
      }
      {
        assertion =
          let
            normalize = url: lib.removeSuffix "/" url;
          in
          normalize cfg.publicBaseUrl == normalize cfg.issuer;
        message = "sys.services.matrix-authentication-service.publicBaseUrl and issuer must match (ignoring trailing slash) for OIDC discovery to work";
      }
      (traefikLib.mkCfTunnelAssertion {
        name = "matrix-authentication-service";
        inherit cfg;
      })
    ];
  };
}
