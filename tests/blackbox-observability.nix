{
  blizzard,
  pkgs,
}:
let
  inherit (pkgs) lib;
  cfg = blizzard.config;
  blackbox = cfg.sys.services.blackbox;
  exporter = cfg.services.prometheus.exporters.blackbox;
  exporterUnit = cfg.systemd.services.prometheus-blackbox-exporter;
  scrape = lib.findFirst (
    item: item.job_name == "blackbox"
  ) null cfg.services.prometheus.scrapeConfigs;
  alertGroups = cfg.services.grafana.provision.alerting.rules.settings.groups;
  availabilityGroup = lib.findFirst (
    group: group.name == "public-service-availability"
  ) null alertGroups;
  availabilityRule = lib.findFirst (
    rule: rule.uid == "public-service-probe-failed"
  ) null availabilityGroup.rules;
  dashboard = builtins.fromJSON (
    builtins.readFile cfg.sys.services.grafana.provision.dashboards.service-availability
  );
  blackboxConfig = builtins.fromJSON (builtins.readFile exporter.configFile);
  expectedTargets = [
    "matrix/client-api"
    "matrix/oidc-discovery"
    "matrix/federation-discovery"
    "matrix/federation-endpoint"
  ];
in
assert blackbox.enable;
assert map (target: "${target.service}/${target.name}") blackbox.targets == expectedTargets;
assert exporter.enable;
assert exporter.listenAddress == "127.0.0.1";
assert exporter.port == 9115;
assert exporterUnit.serviceConfig.AmbientCapabilities == [ ];
assert exporterUnit.serviceConfig.CapabilityBoundingSet == [ ];
assert
  exporterUnit.serviceConfig.RestrictAddressFamilies == [
    "AF_INET"
    "AF_INET6"
  ];
assert builtins.length (builtins.attrNames blackboxConfig.modules) == 4;
assert lib.all (
  module:
  module.prober == "http"
  && module.timeout == "10s"
  && module.http.method == "GET"
  && module.http.valid_status_codes == [ 200 ]
) (builtins.attrValues blackboxConfig.modules);
assert lib.any (pattern: lib.hasInfix "issuer" pattern) (
  blackboxConfig.modules."http_matrix_oidc-discovery".http.fail_if_body_not_matches_regexp
);
assert lib.any (pattern: lib.hasInfix "m\\.server" pattern) (
  blackboxConfig.modules."http_matrix_federation-discovery".http.fail_if_body_not_matches_regexp
);
assert scrape != null;
assert scrape.scrape_interval == "30s";
assert scrape.scrape_timeout == "15s";
assert scrape.metrics_path == "/probe";
assert builtins.length scrape.static_configs == 4;
assert lib.hasPrefix "https://" (builtins.head (builtins.head scrape.static_configs).targets);
assert lib.any (relabel: relabel.target_label or null == "__param_target") scrape.relabel_configs;
assert lib.any (relabel: relabel.target_label or null == "__param_module") scrape.relabel_configs;
assert lib.any (relabel: relabel.target_label or null == "instance") scrape.relabel_configs;
assert lib.any (relabel: relabel.replacement or null == "127.0.0.1:9115") scrape.relabel_configs;
assert availabilityGroup != null;
assert availabilityGroup.interval == "30s";
assert availabilityRule != null;
assert availabilityRule.for == "5m";
assert availabilityRule.noDataState == "OK";
assert lib.hasInfix "probe_success" (builtins.head availabilityRule.data).model.expr;
assert lib.hasInfix ''job="blackbox"'' (builtins.head availabilityRule.data).model.expr;
assert lib.hasInfix "five minutes" availabilityRule.annotations.description;
assert dashboard.uid == "service-availability";
assert dashboard.title == "Public Service Availability";
assert dashboard.refresh == "30s";
assert lib.any (
  panel:
  lib.any (target: lib.hasInfix "probe_success{job=\"blackbox\"}" (target.expr or "")) (
    panel.targets or [ ]
  )
) dashboard.panels;
assert lib.any (
  panel:
  lib.any (target: lib.hasInfix "probe_ssl_earliest_cert_expiry" (target.expr or "")) (
    panel.targets or [ ]
  )
) dashboard.panels;
pkgs.runCommand "blackbox-observability-tests" { } "touch $out"
