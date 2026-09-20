{ config, pkgs, ... }:
let
  csConfig =
    (pkgs.formats.yaml { }).generate "crowdsec.yaml"
      config.services.crowdsec.settings.general;
in
{
  # Investigation storage is local-only. No raw HTTP access logs are forwarded:
  # only the plugin's allowlisted security events and normalized local alerts.
  services.victorialogs = {
    enable = true;
    listenAddress = "127.0.0.1:9428";
    extraOptions = [
      "-retentionPeriod=90d"
      "-retention.maxDiskSpaceUsageBytes=10GiB"
      "-storage.minFreeDiskSpaceBytes=5GiB"
    ];
  };
  services.alloy = {
    enable = true;
    extraFlags = [
      "--server.http.listen-addr=127.0.0.1:12345"
      "--disable-reporting"
    ];
  };
  environment.etc."alloy/crowdsec.alloy".text = ''
    loki.source.journal "crowdsec_requests" {
      matches = "_SYSTEMD_UNIT=traefik.service"
      max_age = "24h"
      labels = {service = "crowdsec", host = "blizzard"}
      forward_to = [loki.process.crowdsec.receiver]
    }
    loki.source.journal "crowdsec_alerts" {
      matches = "_SYSTEMD_UNIT=crowdsec-alert-archive.service"
      max_age = "24h"
      labels = {service = "crowdsec", host = "blizzard"}
      forward_to = [loki.process.crowdsec.receiver]
    }
    loki.process "crowdsec" {
      stage.json {
        expressions = {event = "event", event_time = "time"}
      }
      stage.timestamp {
        source = "event_time"
        format = "RFC3339Nano"
        action_on_failure = "skip"
      }
      stage.labels {
        values = {event = ""}
      }
      stage.match {
        selector = "{event!~\"crowdsec_remediation|crowdsec_alert\"}"
        action = "drop"
        drop_counter_reason = "not_security_event"
      }
      forward_to = [loki.write.security.receiver]
    }
    loki.write "security" {
      endpoint {
        url = "http://127.0.0.1:9428/insert/loki/api/v1/push"
      }
      wal {
        enabled = true
      }
    }
  '';
  systemd.services.crowdsec-alert-archive = {
    description = "Archive normalized CrowdSec alert metadata";
    after = [ "crowdsec.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = config.services.crowdsec.user;
      Group = config.services.crowdsec.group;
      StateDirectory = "crowdsec-alert-archive";
      StateDirectoryMode = "0700";
      # cscli opens the engine database through SQLite, including its WAL/SHM.
      ReadWritePaths = [ (builtins.dirOf config.services.crowdsec.settings.general.db_config.db_path) ];
      ExecStart = "${pkgs.python3}/bin/python3 ${../../../packages/crowdsec-observability/alerts.py} /var/lib/crowdsec-alert-archive/seen.sqlite ${config.services.crowdsec.package}/bin/cscli ${csConfig}";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      TimeoutStartSec = "60s";
      UMask = "0077";
    };
  };
  systemd.timers.crowdsec-alert-archive = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "1m";
    };
  };
  sys.services.prometheus.extraScrapeConfigs =
    map
      (entry: {
        job_name = entry.name;
        static_configs = [ { targets = [ "127.0.0.1:${toString entry.port}" ]; } ];
      })
      [
        {
          name = "crowdsec";
          port = 6060;
        }
        {
          name = "crowdsec-firewall";
          port = 6061;
        }
        {
          name = "security-logs";
          port = 9428;
        }
        {
          name = "security-alloy";
          port = 12345;
        }
      ];
  sys.services.grafana = {
    plugins = [ pkgs.grafanaPlugins.victoriametrics-logs-datasource ];
    provision.datasources = [
      {
        name = "Security logs";
        uid = "security-logs";
        type = "victoriametrics-logs-datasource";
        url = "http://127.0.0.1:9428";
        access = "proxy";
        isDefault = false;
      }
    ];
    provision.dashboards.crowdsec = ../../../dashboards/host/blizzard/crowdsec.json;
  };
}
