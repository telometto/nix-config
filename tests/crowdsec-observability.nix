{ blizzard, pkgs }:
let
  cfg = blizzard.config;
  inherit (pkgs) lib;
  sources = cfg.services.crowdsec.localConfig.acquisitions;
  bouncer = import ../packages/crowdsec-bouncer { inherit pkgs; };
  jobs = map (job: job.job_name) cfg.services.prometheus.scrapeConfigs;
  contexts = cfg.services.crowdsec.localConfig.contexts;
  health = lib.findFirst (
    g: g.name == "crowdsec-health"
  ) null cfg.services.grafana.provision.alerting.rules.settings.groups;
  prometheusRules = lib.filter (r: (builtins.head r.data).datasourceUid == "prometheus") health.rules;
  rulesFile = pkgs.writeText "crowdsec-rules.json" (
    builtins.toJSON {
      groups = [
        {
          name = "crowdsec";
          rules = map (r: {
            alert = r.uid;
            expr = (builtins.head r.data).model.expr;
          }) prometheusRules;
        }
      ];
    }
  );
  unavailable = lib.findFirst (r: r.uid == "crowdsec-unavailable") null prometheusRules;
  ruleTests = pkgs.writeText "crowdsec-rule-tests.json" (
    builtins.toJSON {
      rule_files = [ rulesFile ];
      evaluation_interval = "1m";
      tests =
        map
          (healthy: {
            interval = "1m";
            input_series =
              map
                (job: {
                  series = "up{job=\"${job}\"}";
                  values = if healthy then "1+0x10" else "0+0x10";
                })
                [
                  "crowdsec"
                  "crowdsec-firewall"
                  "security-logs"
                  "security-alloy"
                ];
            promql_expr_test = [
              {
                expr = (builtins.head unavailable.data).model.expr;
                eval_time = "10m";
                exp_samples = [
                  {
                    labels = "{}";
                    value = if healthy then 0 else 4;
                  }
                ];
              }
            ];
          })
          [
            true
            false
          ];
    }
  );
  dashboard = builtins.fromJSON (builtins.readFile ../dashboards/host/blizzard/crowdsec.json);
in
assert lib.any (
  s: lib.elem "_SYSTEMD_UNIT=sshd.service" (s.journalctl_filter or [ ]) && s.labels.type == "syslog"
) sources;
assert lib.any (s: s.source == "appsec" && s.listen_addr == "127.0.0.1:7422") sources;
assert cfg.services.crowdsec.settings.simulation.simulation == false;
assert builtins.length cfg.services.crowdsec.settings.simulation.exclusions == 4;
assert cfg.services.crowdsec.autoUpdateService;
assert lib.any (
  c: (c.context.target_host or [ ]) == [ "req != nil ? req.Host : evt.Meta.target_fqdn" ]
) contexts;
assert cfg.services.crowdsec-firewall-bouncer.enable;
assert cfg.services.crowdsec-firewall-bouncer.settings.iptables_chains == [ "INPUT" ];
assert cfg.services.crowdsec-firewall-bouncer.settings.api_key == "@API_KEY_FILE@";
assert cfg.services.victorialogs.listenAddress == "127.0.0.1:9428";
assert lib.all (job: lib.elem job jobs) [
  "crowdsec"
  "crowdsec-firewall"
  "security-logs"
  "security-alloy"
];
assert
  cfg.services.traefik.staticConfigOptions.experimental.localPlugins.bouncer.moduleName
  == "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin";
assert !(cfg.services.traefik.staticConfigOptions.experimental ? plugins);
assert builtins.length dashboard.panels >= 10;
assert lib.all (rule: rule.condition == "B") health.rules;
pkgs.runCommand "crowdsec-observability-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.prometheus.cli
    ];
    # Builds the patched plugin and its pure Go regression tests too.
    inherit bouncer;
    runtimeSettings = pkgs.writeText "crowdsec-runtime-settings.json" (
      builtins.toJSON {
        appsec = cfg.environment.etc."crowdsec/appsec-configs/blizzard-observe.yaml".source;
        inherit (cfg.services.crowdsec.localConfig) contexts profiles;
        logAlertQueries = map (r: (builtins.head r.data).model.expr) (
          lib.filter (r: (builtins.head r.data).datasourceUid == "security-logs") health.rules
        );
      }
    );
  }
  ''
      mkdir -p source/tests source/packages/crowdsec-observability
      cp ${./crowdsec_observability.py} source/tests/crowdsec_observability.py
      cp ${../packages/crowdsec-observability/alerts.py} source/packages/crowdsec-observability/alerts.py
      cp ${../packages/crowdsec-observability/contexts.py} source/packages/crowdsec-observability/contexts.py
      cp ${../packages/crowdsec-observability/hub-status.py} source/packages/crowdsec-observability/hub-status.py
      python source/tests/crowdsec_observability.py
    promtool check rules ${rulesFile}
    promtool test rules ${ruleTests}
      touch $out
  ''
