{ config, lib, ... }:
let
  cfg = config.sys.services.securityLogArchive;
  specifications = import ../../../lib/security-log-archive-alerts.nix;
  rule = spec: {
    inherit (spec) uid title;
    condition = "B";
    for = spec.hold;
    noDataState = "OK";
    execErrState = "Error";
    isPaused = false;
    labels = {
      service = "security-log-archive";
      inherit (spec) severity;
    };
    annotations = {
      summary = spec.title;
      inherit (spec) description;
    };
    data = [
      {
        refId = "A";
        datasourceUid = "prometheus";
        relativeTimeRange = {
          from = 600;
          to = 0;
        };
        model = {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          refId = "A";
          expr = "count(${spec.expr}) or vector(0)";
          instant = true;
          range = false;
          editorMode = "code";
          intervalMs = 60000;
          maxDataPoints = 43200;
        };
      }
      {
        refId = "B";
        datasourceUid = "__expr__";
        relativeTimeRange = {
          from = 0;
          to = 0;
        };
        model = {
          refId = "B";
          type = "threshold";
          expression = "A";
          conditions = [
            {
              evaluator = {
                type = "gt";
                params = [ 0 ];
              };
              operator.type = "and";
              query.params = [ "B" ];
              reducer = {
                type = "last";
                params = [ ];
              };
              type = "query";
            }
          ];
        };
      }
    ];
  };
in
{
  # Enable only after the runbook's capacity, credential and recovery gates.
  sys.services.securityLogArchive = {
    enable = false;
    sourceHost = "blizzard";
    repositoryName = "blizzard-security-logs";
    repositoryId = null;
  };

  sops.secrets = lib.mkIf cfg.enable {
    "security-log-archive/upload-ssh" = {
      mode = "0400";
    };
    "security-log-archive/password" = {
      mode = "0400";
    };
    "security-log-archive/heartbeat-url" = {
      mode = "0400";
    };
  };
  systemd.services.security-log-archive-upload = lib.mkIf cfg.enable {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };
  services.grafana.provision.alerting.rules.settings.groups = lib.mkIf cfg.enable [
    {
      orgId = 1;
      name = "security-log-archive";
      folder = "Security";
      interval = "1m";
      rules = map rule specifications;
    }
  ];
}
