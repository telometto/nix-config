{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.trigger;

  # Produces a literal "${VAR}" string in the compose YAML without Nix interpolation.
  dol = "$";

  clickhouseOverride = pkgs.writeText "trigger-clickhouse-override.xml" ''
    <clickhouse>
        <logger>
            <level>warning</level>
        </logger>
        <!-- Official recommendations for systems with <16GB RAM -->
        <mark_cache_size>524288000</mark_cache_size>
        <concurrent_threads_soft_limit_num>1</concurrent_threads_soft_limit_num>
        <profiles>
            <default>
                <max_block_size>8192</max_block_size>
                <max_download_threads>1</max_download_threads>
                <input_format_parallel_parsing>0</input_format_parallel_parsing>
                <output_format_parallel_formatting>0</output_format_parallel_formatting>
            </default>
        </profiles>
    </clickhouse>
  '';

  # Merged webapp + worker docker-compose.
  # Secrets are injected at runtime via --env-file /run/trigger/compose.env.
  # All internal service ports are bound to 127.0.0.1 (already upstream defaults).
  # Only the webapp port is exposed on 0.0.0.0 so Traefik can reach it over the bridge.
  composeFile = pkgs.writeText "trigger-docker-compose.yml" ''
    name: trigger

    x-logging: &logging-config
      driver: local
      options:
        max-size: "20m"
        max-file: "5"
        compress: "true"

    services:
      webapp:
        image: ghcr.io/triggerdotdev/trigger.dev:${cfg.imageTag}
        restart: unless-stopped
        logging: *logging-config
        ports:
          - 0.0.0.0:${toString cfg.port}:3000
        depends_on:
          postgres:
            condition: service_healthy
          redis:
            condition: service_healthy
          clickhouse:
            condition: service_healthy
        networks:
          - webapp
          - supervisor
        volumes:
          - shared:/home/node/shared
        user: root
        command: sh -c "chown -R node:node /home/node/shared && exec ./scripts/entrypoint.sh"
        healthcheck:
          test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/healthcheck', res => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]
          interval: 30s
          timeout: 10s
          retries: 5
          start_period: 10s
        environment:
          APP_ORIGIN: ${cfg.appOrigin}
          LOGIN_ORIGIN: ${cfg.appOrigin}
          API_ORIGIN: ${cfg.appOrigin}
          ELECTRIC_ORIGIN: http://electric:3000
          DATABASE_URL: postgresql://postgres:${dol}{POSTGRES_PASSWORD}@postgres:5432/main?schema=public&sslmode=disable
          DIRECT_URL: postgresql://postgres:${dol}{POSTGRES_PASSWORD}@postgres:5432/main?schema=public&sslmode=disable
          SESSION_SECRET: ${dol}{SESSION_SECRET}
          MAGIC_LINK_SECRET: ${dol}{MAGIC_LINK_SECRET}
          ENCRYPTION_KEY: ${dol}{ENCRYPTION_KEY}
          MANAGED_WORKER_SECRET: ${dol}{MANAGED_WORKER_SECRET}
          REDIS_HOST: redis
          REDIS_PORT: "6379"
          REDIS_TLS_DISABLED: "true"
          APP_LOG_LEVEL: info
          DEV_OTEL_EXPORTER_OTLP_ENDPOINT: http://localhost:3000/otel
          DEPLOY_REGISTRY_HOST: localhost:5000
          DEPLOY_REGISTRY_NAMESPACE: trigger
          DEPLOY_REGISTRY_USERNAME: registry-user
          DEPLOY_REGISTRY_PASSWORD: ${dol}{REGISTRY_PASSWORD}
          OBJECT_STORE_BASE_URL: http://minio:9000
          OBJECT_STORE_ACCESS_KEY_ID: admin
          OBJECT_STORE_SECRET_ACCESS_KEY: ${dol}{MINIO_PASSWORD}
          GRACEFUL_SHUTDOWN_TIMEOUT: "1000"
          TRIGGER_BOOTSTRAP_ENABLED: "1"
          TRIGGER_BOOTSTRAP_WORKER_GROUP_NAME: bootstrap
          TRIGGER_BOOTSTRAP_WORKER_TOKEN_PATH: /home/node/shared/worker_token
          CLICKHOUSE_URL: http://default:${dol}{CLICKHOUSE_PASSWORD}@clickhouse:8123?secure=false
          RUN_REPLICATION_ENABLED: "1"
          RUN_REPLICATION_CLICKHOUSE_URL: http://default:${dol}{CLICKHOUSE_PASSWORD}@clickhouse:8123
          TRIGGER_TELEMETRY_DISABLED: "1"
          INTERNAL_OTEL_TRACE_LOGGING_ENABLED: "0"
          # SMTP / magic-link: set by trigger-setup when cfg.smtp.enable is true;
          # empty string when unset causes trigger to fall back to console logging.
          EMAIL_TRANSPORT: ${dol}{EMAIL_TRANSPORT:-}
          FROM_EMAIL: ${dol}{FROM_EMAIL:-}
          REPLY_TO_EMAIL: ${dol}{REPLY_TO_EMAIL:-}
          SMTP_HOST: ${dol}{SMTP_HOST:-}
          SMTP_PORT: ${dol}{SMTP_PORT:-}
          SMTP_USER: ${dol}{SMTP_USER:-}
          SMTP_PASSWORD: ${dol}{SMTP_PASSWORD:-}
          SMTP_SECURE: "false"
          # Access control: empty regex allows all addresses (single-user Tailscale deployment)
          WHITELISTED_EMAILS: ${dol}{WHITELISTED_EMAILS:-}
          ADMIN_EMAILS: ${dol}{ADMIN_EMAILS:-}

      postgres:
        image: postgres:14
        restart: unless-stopped
        logging: *logging-config
        ports:
          - 127.0.0.1:5433:5432
        volumes:
          - postgres:/var/lib/postgresql/data/
        networks:
          - webapp
        command:
          - -c
          - wal_level=logical
        environment:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: ${dol}{POSTGRES_PASSWORD}
          POSTGRES_DB: main
        healthcheck:
          test: ["CMD", "pg_isready", "-U", "postgres"]
          interval: 10s
          timeout: 5s
          retries: 5
          start_period: 10s

      redis:
        image: redis:7
        restart: unless-stopped
        logging: *logging-config
        ports:
          - 127.0.0.1:6389:6379
        volumes:
          - redis:/data
        networks:
          - webapp
        healthcheck:
          test: ["CMD", "redis-cli", "ping"]
          interval: 10s
          timeout: 5s
          retries: 5
          start_period: 10s

      electric:
        image: electricsql/electric:1.2.4
        restart: unless-stopped
        logging: *logging-config
        depends_on:
          postgres:
            condition: service_healthy
        networks:
          - webapp
        environment:
          DATABASE_URL: postgresql://postgres:${dol}{POSTGRES_PASSWORD}@postgres:5432/main?schema=public&sslmode=disable
          ELECTRIC_INSECURE: "true"
          ELECTRIC_USAGE_REPORTING: "false"
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:3000/v1/health"]
          interval: 10s
          timeout: 5s
          retries: 5
          start_period: 10s

      clickhouse:
        image: bitnamilegacy/clickhouse:${cfg.clickhouseImageTag}
        restart: unless-stopped
        logging: *logging-config
        ports:
          - 127.0.0.1:9123:8123
          - 127.0.0.1:9090:9000
        environment:
          CLICKHOUSE_ADMIN_USER: default
          CLICKHOUSE_ADMIN_PASSWORD: ${dol}{CLICKHOUSE_PASSWORD}
        volumes:
          - clickhouse:/bitnami/clickhouse
          - ${clickhouseOverride}:/bitnami/clickhouse/etc/config.d/override.xml:ro
        networks:
          - webapp
        healthcheck:
          test: ["CMD-SHELL", "clickhouse-client --host localhost --port 9000 --user default --password $$CLICKHOUSE_ADMIN_PASSWORD --query 'SELECT 1'"]
          interval: 5s
          timeout: 5s
          retries: 5
          start_period: 10s

      registry:
        image: registry:2
        restart: unless-stopped
        logging: *logging-config
        ports:
          - 127.0.0.1:5000:5000
        networks:
          - webapp
        volumes:
          - /run/trigger/registry/auth.htpasswd:/auth/htpasswd:ro
        environment:
          REGISTRY_AUTH: htpasswd
          REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
          REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
        healthcheck:
          test: ["CMD", "wget", "--spider", "-q", "http://localhost:5000/"]
          interval: 10s
          timeout: 5s
          retries: 5
          start_period: 10s

      minio:
        image: bitnamilegacy/minio:${cfg.minioImageTag}
        restart: unless-stopped
        logging: *logging-config
        ports:
          - 127.0.0.1:9000:9000
          - 127.0.0.1:9001:9001
        networks:
          - webapp
        volumes:
          - minio:/bitnami/minio/data
        environment:
          MINIO_ROOT_USER: admin
          MINIO_ROOT_PASSWORD: ${dol}{MINIO_PASSWORD}
          MINIO_DEFAULT_BUCKETS: packets
          MINIO_BROWSER: "on"
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
          interval: 5s
          timeout: 10s
          retries: 5
          start_period: 10s

      supervisor:
        image: ghcr.io/triggerdotdev/supervisor:${cfg.imageTag}
        restart: unless-stopped
        logging: *logging-config
        depends_on:
          - docker-proxy
        networks:
          - supervisor
          - docker-proxy
          - webapp
        volumes:
          - shared:/home/node/shared
        user: root
        command: sh -c "chown -R node:node /home/node/shared && exec /usr/bin/dumb-init -- pnpm run --filter supervisor start"
        environment:
          TRIGGER_WORKER_TOKEN: file:///home/node/shared/worker_token
          MANAGED_WORKER_SECRET: ${dol}{MANAGED_WORKER_SECRET}
          TRIGGER_API_URL: http://webapp:3000
          OTEL_EXPORTER_OTLP_ENDPOINT: http://webapp:3000/otel
          TRIGGER_WORKLOAD_API_DOMAIN: supervisor
          TRIGGER_WORKLOAD_API_PORT_EXTERNAL: "8020"
          DOCKER_HOST: tcp://docker-proxy:2375
          DOCKER_RUNNER_NETWORKS: webapp,supervisor
          DOCKER_REGISTRY_URL: localhost:5000
          DOCKER_REGISTRY_USERNAME: registry-user
          DOCKER_REGISTRY_PASSWORD: ${dol}{REGISTRY_PASSWORD}
          DOCKER_AUTOREMOVE_EXITED_CONTAINERS: "0"
          ENFORCE_MACHINE_PRESETS: "1"
        healthcheck:
          test: ["CMD", "node", "-e", "require('http').get('http://localhost:8020/health', res => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]
          interval: 30s
          timeout: 10s
          retries: 5
          start_period: 10s

      docker-proxy:
        image: tecnativa/docker-socket-proxy:${cfg.dockerSocketProxyImageTag}
        restart: unless-stopped
        logging: *logging-config
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock:ro
        networks:
          - docker-proxy
        environment:
          LOG_LEVEL: info
          POST: "1"
          CONTAINERS: "1"
          IMAGES: "1"
          INFO: "1"
          NETWORKS: "1"
        healthcheck:
          test: ["CMD", "nc", "-z", "127.0.0.1", "2375"]
          interval: 30s
          timeout: 5s
          retries: 5
          start_period: 5s

    volumes:
      clickhouse:
      postgres:
      redis:
      shared:
      minio:

    networks:
      docker-proxy:
        name: docker-proxy
      supervisor:
        name: supervisor
      webapp:
        name: webapp
  '';
in
{
  options.sys.services.trigger = {
    enable = lib.mkEnableOption "trigger.dev background job platform";

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port the webapp container publishes on the VM (forwarded to Traefik on the host).";
    };

    appOrigin = lib.mkOption {
      type = lib.types.str;
      description = "Public HTTPS URL for the webapp (used in emails, CLI config, and CORS).";
      example = "https://triggers.example.com";
    };

    imageTag = lib.mkOption {
      type = lib.types.str;
      default = "v4.4.5";
      description = "Docker image tag for ghcr.io/triggerdotdev/trigger.dev and supervisor.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/trigger";
      description = "Persistent volume root; Docker's data-root lives at <dataDir>/docker.";
    };

    clickhouseImageTag = lib.mkOption {
      type = lib.types.str;
      # 24.12 is the last release before ClickHouse 25.x introduced a
      # restriction that breaks trigger.dev migration 003 (CREATE VIEW with
      # JSON/Dynamic columns).  The trigger-ch-migrate-fixup service handles
      # the symptom, but pinning here avoids hitting the bug entirely.
      default = "24.12";
      description = "Docker image tag for bitnamilegacy/clickhouse.";
    };

    minioImageTag = lib.mkOption {
      type = lib.types.str;
      default = "2025.4.22";
      description = "Docker image tag for bitnamilegacy/minio.";
    };

    dockerSocketProxyImageTag = lib.mkOption {
      type = lib.types.str;
      default = "0.3.0";
      description = "Docker image tag for tecnativa/docker-socket-proxy.";
    };

    smtp = {
      enable = lib.mkEnableOption "SMTP transport for magic-link emails" // {
        default = false;
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "smtp.protonmail.ch";
        description = "SMTP server hostname.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 587;
        description = "SMTP server port (587 = STARTTLS).";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "SMTP authentication username (the sending email address).";
      };

      fromEmail = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "FROM address for magic-link emails.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Path to file containing the SMTP password (sops secret path).";
      };
    };

    auth = {
      whitelistedEmailsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing a regex of permitted email addresses. Null allows all.";
      };

      adminEmailsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing a regex of emails auto-promoted to admin. When null, ADMIN_EMAILS is set to an empty string in the container (no auto-promotion).";
      };
    };

    secrets = {
      sessionSecretFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to 32-hex-char SESSION_SECRET (openssl rand -hex 16).";
      };

      magicLinkSecretFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to 32-hex-char MAGIC_LINK_SECRET (openssl rand -hex 16).";
      };

      encryptionKeyFile = lib.mkOption {
        type = lib.types.str;
        # The webapp enforces Buffer.from(val, "utf8").length === 32 at startup.
        # openssl rand -hex 16 produces exactly 32 ASCII hex characters (= 32 bytes).
        # openssl rand -hex 32 produces 64 characters and will be rejected.
        description = "Path to ENCRYPTION_KEY file. Must contain exactly 32 UTF-8 bytes (openssl rand -hex 16).";
      };

      managedWorkerSecretFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to MANAGED_WORKER_SECRET shared between webapp and supervisor.";
      };

      registryPasswordFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to password for the bundled Docker registry (registry-user account).";
      };

      minioPasswordFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to MinIO root password (also used as OBJECT_STORE_SECRET_ACCESS_KEY).";
      };

      postgresPasswordFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to Postgres root password (used for POSTGRES_PASSWORD and all DATABASE_URL/DIRECT_URL connections).";
      };

      clickhousePasswordFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to ClickHouse admin password (used for CLICKHOUSE_ADMIN_PASSWORD and all ClickHouse connection URLs).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.smtp.enable || cfg.smtp.passwordFile != "";
        message = "sys.services.trigger: smtp.passwordFile must be set when smtp.enable = true";
      }
      {
        assertion = !cfg.smtp.enable || cfg.smtp.username != "";
        message = "sys.services.trigger: smtp.username must be set when smtp.enable = true";
      }
      {
        assertion = !cfg.smtp.enable || cfg.smtp.fromEmail != "";
        message = "sys.services.trigger: smtp.fromEmail must be set when smtp.enable = true";
      }
    ];

    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        # Store all images and named volumes on the persistent volume.
        data-root = "${cfg.dataDir}/docker";
      };
    };

    systemd = {
      tmpfiles.rules = [
        "d ${cfg.dataDir} 0700 root root -"
        "d ${cfg.dataDir}/docker 0700 root root -"
        "d /run/trigger 0700 root root -"
        "d /run/trigger/registry 0700 root root -"
      ];

      services = {
        trigger-setup = {
          description = "Build trigger.dev runtime env file and registry credentials from sops secrets";
          after = [ "sops-install-secrets.service" ];
          requires = [ "sops-install-secrets.service" ];
          before = [ "trigger-compose.service" ];
          requiredBy = [ "trigger-compose.service" ];
          path = [
            pkgs.apacheHttpd
            pkgs.coreutils
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -euo pipefail

            # Write runtime env file with all secrets for docker-compose substitution.
            {
              printf 'SESSION_SECRET=%s\n'        "$(tr -d '\n' < ${lib.escapeShellArg cfg.secrets.sessionSecretFile})"
              printf 'MAGIC_LINK_SECRET=%s\n'     "$(tr -d '\n' < ${lib.escapeShellArg cfg.secrets.magicLinkSecretFile})"
              printf 'ENCRYPTION_KEY=%s\n'        "$(tr -d '\n' < ${lib.escapeShellArg cfg.secrets.encryptionKeyFile})"
              printf 'MANAGED_WORKER_SECRET=%s\n' "$(tr -d '\n' < ${lib.escapeShellArg cfg.secrets.managedWorkerSecretFile})"
              printf 'REGISTRY_PASSWORD=%s\n'     "$(tr -d '\n' < ${lib.escapeShellArg cfg.secrets.registryPasswordFile})"
              printf 'MINIO_PASSWORD=%s\n'        "$(tr -d '\n' < ${lib.escapeShellArg cfg.secrets.minioPasswordFile})"
              printf 'POSTGRES_PASSWORD=%s\n'    "$(tr -d '\n' < ${lib.escapeShellArg cfg.secrets.postgresPasswordFile})"
              printf 'CLICKHOUSE_PASSWORD=%s\n'  "$(tr -d '\n' < ${lib.escapeShellArg cfg.secrets.clickhousePasswordFile})"
              ${lib.optionalString cfg.smtp.enable ''
                printf 'EMAIL_TRANSPORT=smtp\n'
                printf 'FROM_EMAIL=%s\n'    ${lib.escapeShellArg cfg.smtp.fromEmail}
                printf 'REPLY_TO_EMAIL=%s\n' ${lib.escapeShellArg cfg.smtp.fromEmail}
                printf 'SMTP_HOST=%s\n'    ${lib.escapeShellArg cfg.smtp.host}
                printf 'SMTP_PORT=%s\n'    ${lib.escapeShellArg (toString cfg.smtp.port)}
                printf 'SMTP_USER=%s\n'    ${lib.escapeShellArg cfg.smtp.username}
                printf 'SMTP_PASSWORD=%s\n' "$(tr -d '\n' < ${lib.escapeShellArg cfg.smtp.passwordFile})"
              ''}
              ${lib.optionalString (cfg.auth.whitelistedEmailsFile != null) ''
                printf 'WHITELISTED_EMAILS=%s\n' "$(tr -d '\n' < ${lib.escapeShellArg cfg.auth.whitelistedEmailsFile})"
              ''}
              ${lib.optionalString (cfg.auth.adminEmailsFile != null) ''
                printf 'ADMIN_EMAILS=%s\n' "$(tr -d '\n' < ${lib.escapeShellArg cfg.auth.adminEmailsFile})"
              ''}
            } > /run/trigger/compose.env
            chmod 600 /run/trigger/compose.env

            # Generate bcrypt htpasswd for the bundled Docker registry.
            REGISTRY_PASSWORD=$(tr -d '\n' < ${lib.escapeShellArg cfg.secrets.registryPasswordFile})
            htpasswd -bnBC 10 "registry-user" "$REGISTRY_PASSWORD" > /run/trigger/registry/auth.htpasswd
            chmod 600 /run/trigger/registry/auth.htpasswd
          '';
        };

        # Migration 003 in trigger.dev 4.x attempts to CREATE VIEW with
        # JSON/Dynamic columns, which ClickHouse 25.x rejects.  Because
        # ClickHouse DDL is non-transactional, the tables created earlier in
        # the same migration file persist, but goose never writes the version
        # record.  On every subsequent start the webapp retries the migration
        # and hits TABLE_ALREADY_EXISTS, crash-looping forever.
        #
        # This service boots ClickHouse alone, detects the inconsistency, and
        # inserts the missing goose_db_version records so the webapp can
        # proceed normally when trigger-compose starts the full stack.
        trigger-ch-migrate-fixup = {
          description = "Repair trigger.dev ClickHouse goose migration state before stack startup";
          after = [
            "docker.service"
            "trigger-setup.service"
          ];
          requires = [
            "docker.service"
            "trigger-setup.service"
          ];
          before = [ "trigger-compose.service" ];
          requiredBy = [ "trigger-compose.service" ];
          path = [
            pkgs.docker
            pkgs.coreutils
            pkgs.gnugrep
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -euo pipefail

            # Boot ClickHouse alone so we can inspect migration state.
            # trigger-compose will start the full stack afterwards; it will
            # find ClickHouse already running and not restart it.
            ${pkgs.docker}/bin/docker compose \
              -f ${composeFile} \
              --env-file /run/trigger/compose.env \
              --project-directory ${cfg.dataDir} \
              up -d clickhouse

            # Wait up to 60 s for ClickHouse to become healthy.
            for i in $(seq 1 60); do
              STATUS=$(${pkgs.docker}/bin/docker inspect \
                --format '{{.State.Health.Status}}' trigger-clickhouse-1 2>/dev/null || true)
              [ "$STATUS" = "healthy" ] && break
              sleep 1
            done
            [ "$STATUS" = "healthy" ] || { echo "ClickHouse did not become healthy after 60 s"; exit 1; }

            line=$(grep '^CLICKHOUSE_PASSWORD=' /run/trigger/compose.env)
            CHPASS=''${line#CLICKHOUSE_PASSWORD=}
            ch() {
              ${pkgs.docker}/bin/docker exec trigger-clickhouse-1 \
                clickhouse-client --user default --password "$CHPASS" \
                --database trigger_dev --query "$1"
            }

            # Skip all checks on a first-ever install (goose_db_version does not exist yet).
            GOOSE_TABLE=$(ch "SELECT count() FROM system.tables WHERE database='trigger_dev' AND name='goose_db_version'" 2>/dev/null || echo 0)
            [ "$GOOSE_TABLE" = "0" ] && exit 0

            # Migration 003: task_runs_v1 + raw_task_runs_payload_v1 created,
            # but the trailing CREATE VIEW fails on ClickHouse 25.x (JSON/Dynamic
            # columns not allowed in Views).  Mark applied if the table exists
            # but the version record is missing.
            TNAME=task_runs_v1
            if [ "$(ch "SELECT count() FROM system.tables WHERE database='trigger_dev' AND name='$TNAME'" 2>/dev/null || echo 0)" = "1" ] && \
               [ "$(ch "SELECT count() FROM goose_db_version WHERE version_id=3 AND is_applied=1" 2>/dev/null || echo 0)" = "0" ]; then
              ch "INSERT INTO goose_db_version (version_id, is_applied) VALUES (3, 1)"
            fi

            # Migration 004: task_runs_v2.  Apply the same guard in case the
            # data volume outlived a goose_db_version reset.
            TNAME=task_runs_v2
            if [ "$(ch "SELECT count() FROM system.tables WHERE database='trigger_dev' AND name='$TNAME'" 2>/dev/null || echo 0)" = "1" ] && \
               [ "$(ch "SELECT count() FROM goose_db_version WHERE version_id=4 AND is_applied=1" 2>/dev/null || echo 0)" = "0" ]; then
              ch "INSERT INTO goose_db_version (version_id, is_applied) VALUES (4, 1)"
            fi
          '';
        };

        trigger-compose = {
          description = "trigger.dev v4 docker-compose stack";
          after = [
            "docker.service"
            "trigger-setup.service"
            "trigger-ch-migrate-fixup.service"
            "network-online.target"
          ];
          requires = [
            "docker.service"
            "trigger-setup.service"
            "trigger-ch-migrate-fixup.service"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.docker}/bin/docker compose -f ${composeFile} --env-file /run/trigger/compose.env --project-directory ${cfg.dataDir} up -d --remove-orphans";
            ExecStop = "${pkgs.docker}/bin/docker compose -f ${composeFile} --project-directory ${cfg.dataDir} down";
            TimeoutStartSec = "300";
            TimeoutStopSec = "120";
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
