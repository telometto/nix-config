{ config, lib, ... }:
let
  cfg = config.sys.services.securityLogArchive;
  grafanaAlerts = import ../../../lib/grafana-alerts.nix;
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
      (grafanaAlerts.prometheusQuery { expr = "count(${spec.expr}) or vector(0)"; })
      grafanaAlerts.threshold
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
