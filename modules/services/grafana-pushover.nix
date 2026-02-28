{
  lib,
  config,
  ...
}:
let
  cfg = config.sys.services.grafanaPushover;
in
{
  options.sys.services.grafanaPushover = {
    enable = lib.mkEnableOption "Pushover notifications for Grafana alerting";

    apiTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.sys.secrets.pushoverApiTokenFile or null;
      description = "Path to file containing the Pushover application API token";
    };

    userKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.sys.secrets.pushoverUserKeyFile or null;
      description = "Path to file containing the Pushover user/group key";
    };
  };

  config = lib.mkIf cfg.enable {
    services.grafana.provision.alerting = {
      contactPoints.settings = {
        apiVersion = 1;
        contactPoints = [
          {
            orgId = 1;
            name = "pushover";
            receivers = [
              {
                uid = "pushover-default";
                type = "pushover";
                settings = {
                  apiToken = "$__file{${cfg.apiTokenFile}}";
                  userKey = "$__file{${cfg.userKeyFile}}";
                  priority = "0";
                  okPriority = "-1";
                  retry = "60";
                  expire = "3600";
                };
              }
            ];
          }
        ];
      };

      policies.settings = {
        apiVersion = 1;
        policies = [
          {
            orgId = 1;
            receiver = "pushover";
            group_by = [
              "grafana_folder"
              "alertname"
            ];
            group_wait = "30s";
            group_interval = "5m";
            repeat_interval = "4h";
          }
        ];
      };
    };

    # Grafana needs read access to the Pushover secret files
    systemd.services.grafana.serviceConfig.BindReadOnlyPaths =
      lib.mkIf (cfg.apiTokenFile != null && cfg.userKeyFile != null)
        [
          cfg.apiTokenFile
          cfg.userKeyFile
        ];

    assertions = [
      {
        assertion = cfg.apiTokenFile != null;
        message = "sys.services.grafanaPushover.apiTokenFile must be set (provide via SOPS)";
      }
      {
        assertion = cfg.userKeyFile != null;
        message = "sys.services.grafanaPushover.userKeyFile must be set (provide via SOPS)";
      }
    ];
  };
}
