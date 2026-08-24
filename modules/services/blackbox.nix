{
  config,
  lib,
  pkgs,
  consts,
  ...
}:
let
  cfg = config.sys.services.blackbox;
  blackboxConstants = consts.blackbox;
  blackboxPort = consts.blackboxPort;

  targetType = lib.types.submodule {
    options = {
      service = lib.mkOption {
        type = lib.types.strMatching "[a-z][a-z0-9_-]*";
        description = "Stable service label used by availability metrics and alerts.";
      };

      name = lib.mkOption {
        type = lib.types.strMatching "[a-z][a-z0-9_-]*";
        description = "Stable name for the public probe.";
      };

      url = lib.mkOption {
        type = lib.types.str;
        description = "Public URL to probe.";
      };

      requiredJsonFields = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "JSON object fields that must be present in a successful response.";
      };

      expectedJsonFields = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "JSON object fields whose string values must match exactly.";
      };
    };
  };

  moduleName = target: "http_${target.service}_${target.name}";

  bodyPatterns =
    target:
    (map (field: ''"${lib.escapeRegex field}"[[:space:]]*:'') target.requiredJsonFields)
    ++ (lib.mapAttrsToList (
      field: value: ''"${lib.escapeRegex field}"[[:space:]]*:[[:space:]]*"${lib.escapeRegex value}"''
    ) target.expectedJsonFields);

  blackboxModule = target: {
    prober = "http";
    timeout = blackboxConstants.probeTimeout;
    http = {
      follow_redirects = false;
      method = "GET";
      preferred_ip_protocol = "ip4";
      valid_http_versions = [
        "HTTP/1.1"
        "HTTP/2.0"
      ];
      valid_status_codes = [ 200 ];
    }
    // lib.optionalAttrs (bodyPatterns target != [ ]) {
      fail_if_body_not_matches_regexp = bodyPatterns target;
    };
  };

  blackboxConfig = {
    modules = lib.listToAttrs (
      map (target: {
        name = moduleName target;
        value = blackboxModule target;
      }) cfg.targets
    );
  };

  scrapeConfig = {
    job_name = blackboxConstants.jobName;
    scrape_interval = blackboxConstants.scrapeInterval;
    scrape_timeout = blackboxConstants.scrapeTimeout;
    metrics_path = "/probe";
    static_configs = map (target: {
      targets = [ target.url ];
      labels = {
        blackbox_module = moduleName target;
        probe = target.name;
        inherit (target) service;
      };
    }) cfg.targets;
    relabel_configs = [
      {
        source_labels = [ "__address__" ];
        target_label = "__param_target";
      }
      {
        source_labels = [ "blackbox_module" ];
        target_label = "__param_module";
      }
      {
        source_labels = [ "__param_target" ];
        target_label = "instance";
      }
      {
        target_label = "__address__";
        replacement = "127.0.0.1:${toString blackboxPort}";
      }
      {
        action = "labeldrop";
        regex = "blackbox_module";
      }
    ];
  };

  prometheusDatasource = {
    type = "prometheus";
    uid = "prometheus";
  };

  ruleData = expr: {
    refId = "A";
    relativeTimeRange = {
      from = blackboxConstants.lookbackSeconds;
      to = 0;
    };
    datasourceUid = prometheusDatasource.uid;
    model = {
      datasource = prometheusDatasource;
      editorMode = "code";
      inherit expr;
      instant = true;
      interval = "";
      intervalMs = blackboxConstants.scrapeIntervalMs;
      maxDataPoints = 43200;
      range = false;
      refId = "A";
    };
  };

  probeFailureExpr = ''min by (service, probe) (probe_success{job="${blackboxConstants.jobName}"}) < 1'';
  exporterScrapeFailureExpr = ''min(up{job="${blackboxConstants.jobName}"}) < 1 or absent(up{job="${blackboxConstants.jobName}"})'';
  targetMissingExpr = lib.concatStringsSep " or " (
    map (
      target:
      ''absent(probe_success{job="${blackboxConstants.jobName}",service="${target.service}",probe="${target.name}"})''
    ) cfg.targets
  );

  availabilityRule = {
    uid = "public-service-probe-failed";
    title = "Public service probe failed";
    condition = "A";
    execErrState = "Error";
    for = blackboxConstants.failureWindow;
    isPaused = false;
    noDataState = "Alerting";
    data = [ (ruleData probeFailureExpr) ];
    annotations = {
      summary = "Public {{ $labels.service }} probe failed: {{ $labels.probe }}";
      description = "The public probe has failed continuously for five minutes. Check the public route, Cloudflare Tunnel, Traefik/CrowdSec, and the target service.";
    };
    labels = {
      alert_group = "public-service-availability";
      severity = "critical";
    };
  };

  targetCoverageRule = {
    uid = "public-service-probe-missing";
    title = "Public service probe series missing";
    condition = "A";
    execErrState = "Error";
    for = blackboxConstants.failureWindow;
    isPaused = false;
    # An empty result is normal while every configured target series exists.
    # The exporter scrape rule covers a missing Prometheus/exporter pipeline.
    noDataState = "OK";
    data = [ (ruleData targetMissingExpr) ];
    annotations = {
      summary = "Public {{ $labels.service }} probe series missing: {{ $labels.probe }}";
      description = "A configured public probe series has disappeared. Check Prometheus target discovery and the blackbox exporter scrape.";
    };
    labels = {
      alert_group = "public-service-availability";
      severity = "critical";
    };
  };

  exporterScrapeRule = {
    uid = "blackbox-exporter-scrape-failed";
    title = "Blackbox exporter scrape failed";
    condition = "A";
    execErrState = "Error";
    for = blackboxConstants.failureWindow;
    isPaused = false;
    noDataState = "Alerting";
    data = [ (ruleData exporterScrapeFailureExpr) ];
    annotations = {
      summary = "Blackbox exporter scrape failed";
      description = "Prometheus cannot scrape the local blackbox exporter. Check prometheus-blackbox-exporter.service and its probe configuration.";
    };
    labels = {
      alert_group = "public-service-availability";
      severity = "critical";
    };
  };

  availabilityRuleGroup = {
    orgId = 1;
    name = "public-service-availability";
    folder = "Service Availability";
    interval = blackboxConstants.scrapeInterval;
    rules = [
      availabilityRule
      exporterScrapeRule
      targetCoverageRule
    ];
  };

  targetKeys = map (target: "${target.service}/${target.name}") cfg.targets;
  moduleNames = map moduleName cfg.targets;
in
{
  options.sys.services.blackbox = {
    enable = lib.mkEnableOption "Prometheus blackbox public availability probes";

    targets = lib.mkOption {
      type = lib.types.listOf targetType;
      default = [ ];
      description = ''
        Public endpoints to probe. The module owns the exporter modules,
        Prometheus relabeling, common alert, and availability labels.
      '';
      example = lib.literalExpression ''
        [
          {
            service = "example";
            name = "homepage";
            url = "https://example.com/";
          }
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.targets != [ ];
        message = "sys.services.blackbox.targets must not be empty when blackbox probes are enabled";
      }
      {
        assertion = builtins.length targetKeys == builtins.length (lib.unique targetKeys);
        message = "sys.services.blackbox target service/name pairs must be unique";
      }
      {
        assertion = builtins.length moduleNames == builtins.length (lib.unique moduleNames);
        message = "sys.services.blackbox target service/name pairs must produce unique blackbox exporter module names";
      }
      {
        assertion = config.sys.services.prometheus.enable or false;
        message = "sys.services.blackbox requires sys.services.prometheus.enable";
      }
    ];

    services.prometheus.exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = blackboxPort;
      configFile = pkgs.writeText "blackbox-exporter.json" (builtins.toJSON blackboxConfig);
      enableConfigCheck = true;
    };

    sys.services.prometheus.extraScrapeConfigs = [ scrapeConfig ];

    # HTTP/TLS probes do not use ICMP. Remove the upstream module's default
    # CAP_NET_RAW and keep the exporter read-only apart from its runtime state.
    systemd.services.prometheus-blackbox-exporter.serviceConfig = {
      AmbientCapabilities = lib.mkForce [ ];
      CapabilityBoundingSet = lib.mkForce [ ];
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = lib.mkForce [
        "AF_INET"
        "AF_INET6"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    };

    services.grafana.provision.alerting.rules.settings.groups =
      lib.mkIf (config.sys.services.grafana.enable or false)
        (lib.mkAfter [ availabilityRuleGroup ]);
  };
}
