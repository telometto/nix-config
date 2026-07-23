{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.cloudflareMetrics;

  isNonEmptyPath = path: path != null && path != "";

  positiveDurationType = lib.types.addCheck lib.types.str (
    value:
    builtins.match "[[:space:]]*([0-9]*[1-9][0-9]*)[[:space:]]*(s|sec|m|min|h|hr|d|day)s?[[:space:]]*" (
      lib.toLower value
    ) != null
  );

  collector = pkgs.stdenvNoCC.mkDerivation {
    pname = "cloudflare-metrics";
    version = "0.1.0";
    src = ./scripts/cloudflare_metrics.py;
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/cloudflare-metrics"
      runHook postInstall
    '';
  };
in
{
  options.sys.services.cloudflareMetrics = {
    enable = lib.mkEnableOption "Cloudflare analytics and Access Prometheus collector";

    port = lib.mkOption {
      type = lib.types.port;
      default = 11015;
      description = "Loopback port on which the collector exposes Prometheus metrics.";
    };

    apiTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Runtime path to a file containing the least-privilege Cloudflare API token.
        The token requires Zone Read, Analytics Read for the monitored zones,
        Access Audit Logs Read, and Access Apps and Policies Read permissions.
        Account Analytics Read adds the optional non-identity Access feed.
      '';
      example = "/run/secrets/cloudflare-metrics-api-token";
    };

    accountIdFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime path to a file containing the Cloudflare account ID.";
      example = "/run/secrets/cloudflare-account-id";
    };

    ownerEmailsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Runtime path to a file containing one expected Cloudflare Access owner email
        address per line.
      '';
      example = "/run/secrets/cloudflare-access-owner-emails";
    };

    analyticsInterval = lib.mkOption {
      type = positiveDurationType;
      default = "5m";
      description = ''
        How often the collector polls Cloudflare HTTP analytics, as a positive
        duration such as 30s, 5m, 2h, or 1d.
      '';
    };

    accessInterval = lib.mkOption {
      type = positiveDurationType;
      default = "1m";
      description = ''
        How often the collector polls Cloudflare Access authentication logs, as
        a positive duration such as 30s, 5m, 2h, or 1d.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = isNonEmptyPath cfg.apiTokenFile;
        message = "sys.services.cloudflareMetrics.apiTokenFile must be set when the collector is enabled.";
      }
      {
        assertion = isNonEmptyPath cfg.accountIdFile;
        message = "sys.services.cloudflareMetrics.accountIdFile must be set when the collector is enabled.";
      }
      {
        assertion = isNonEmptyPath cfg.ownerEmailsFile;
        message = "sys.services.cloudflareMetrics.ownerEmailsFile must be set when the collector is enabled.";
      }
    ];

    systemd.services.cloudflare-metrics = {
      description = "Cloudflare analytics and Access Prometheus collector";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        LISTEN_ADDRESS = "127.0.0.1";
        LISTEN_PORT = toString cfg.port;
        ANALYTICS_INTERVAL = cfg.analyticsInterval;
        ACCESS_INTERVAL = cfg.accessInterval;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.python3}/bin/python3 ${collector}/bin/cloudflare-metrics";
        Restart = "on-failure";
        RestartSec = "10s";

        LoadCredential =
          lib.optional (isNonEmptyPath cfg.apiTokenFile) "api-token:${cfg.apiTokenFile}"
          ++ lib.optional (isNonEmptyPath cfg.accountIdFile) "account-id:${cfg.accountIdFile}"
          ++ lib.optional (isNonEmptyPath cfg.ownerEmailsFile) "owner-emails:${cfg.ownerEmailsFile}";

        DynamicUser = true;
        StateDirectory = "cloudflare-metrics";
        StateDirectoryMode = "0700";
        UMask = "0077";

        AmbientCapabilities = "";
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
      };
    };
  };
}
