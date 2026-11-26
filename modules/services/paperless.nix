{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.paperless;
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
  secretConsumers = [
    "paperless-scheduler"
    "paperless-web"
    "paperless-consumer"
    "paperless-task-queue"
  ]
  ++ lib.optional config.services.paperless.exporter.enable "paperless-exporter";
  secretEnvironment = import ../../lib/runtime-secret-environment.nix {
    inherit lib pkgs;
    name = "paperless";
    variable = "PAPERLESS_SECRET_KEY";
    source = cfg.secretKeyFile;
    group = config.services.paperless.group;
    requiredBy = map (name: "${name}.service") secretConsumers;
  };
in
{
  options.sys.services.paperless = {
    enable = lib.mkEnableOption "Paperless-ngx document management";

    address = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 28981;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = config.sys.secrets.paperlessKeyFile or null;
      description = "Path to file containing the superuser password";
    };

    database.createLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Configure local PostgreSQL for Paperless";
    };

    configureTika = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Tika and Gotenberg for Office/email document processing";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.sys.secrets.paperlessSecretKeyFile or null;
      description = "Path to file containing the secret key for session tokens";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra PAPERLESS_* environment variable settings";
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "paperless"; };
  };

  config = lib.mkIf cfg.enable {
    services = {
      postgresql = lib.mkIf cfg.database.createLocally {
        enable = true;

        initialScript = pkgs.writeText "paperless-init.sql" ''
          CREATE ROLE "paperless" WITH LOGIN;
          CREATE DATABASE "paperless"
            WITH OWNER "paperless"
                 TEMPLATE template0
                 LC_COLLATE = "C"
                 LC_CTYPE = "C";
        '';
      };

      paperless = {
        enable = true;
        inherit (cfg)
          address
          port
          passwordFile
          ;

        database.createLocally = cfg.database.createLocally;
        inherit (cfg) configureTika;
        environmentFile = lib.mkIf (cfg.secretKeyFile != null) secretEnvironment.path;

        settings = {
          PAPERLESS_OCR_LANGUAGE = lib.mkDefault "eng+nor+ita";
          PAPERLESS_OCR_MODE = lib.mkDefault "skip";
          PAPERLESS_OCR_OUTPUT_TYPE = lib.mkDefault "pdfa";
          PAPERLESS_OCR_SKIP_ARCHIVE_FILE = lib.mkDefault "never";

          PAPERLESS_DATE_PARSER_LANGUAGES = lib.mkDefault "en+nb+it";
          PAPERLESS_DATE_ORDER = lib.mkDefault "YMD";

          PAPERLESS_TIME_ZONE = lib.mkDefault (config.time.timeZone or "UTC");
        }
        // lib.optionalAttrs (cfg.reverseProxy.enable && cfg.reverseProxy.domain != null) {
          PAPERLESS_URL = "https://${cfg.reverseProxy.domain}";
        }
        // cfg.settings;
      };

      traefik.dynamic.files.paperless = traefikLib.mkTraefikDynamicConfig {
        name = "paperless";
        inherit cfg config;
        inherit (cfg) port;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services = lib.mkIf (cfg.secretKeyFile != null) {
      paperless-secret-environment = secretEnvironment.service // {
        # Exporting stops the app units. Keep their shared runtime environment
        # available for the exporter and management wrapper while they stop.
        partOf = [ ];
      };
      # The pinned upstream launcher always replaces the environment's key
      # with a generated file. Preserve its launch command and all other unit
      # settings, using the supplied runtime key when one is configured.
      paperless-web.script = lib.mkForce ''
        if [[ -z "''${PAPERLESS_SECRET_KEY:-}" ]]; then
          echo "PAPERLESS_SECRET_KEY is empty, refusing to start." >&2
          exit 1
        fi
        exec ${lib.getExe config.services.paperless.package.python.pkgs.granian} --interface asginl --ws "paperless.asgi:application"
      '';
    };

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.paperless.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      (traefikLib.mkCfTunnelAssertion {
        name = "paperless";
        inherit cfg;
      })
    ];
  };
}
