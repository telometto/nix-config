{
  blizzard,
  pkgs,
  publicDomain,
}:
let
  inherit (pkgs) lib;
  blackboxConstants = (import ../lib/constants.nix).blackbox;
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
  exporterScrapeRule = lib.findFirst (
    rule: rule.uid == "blackbox-exporter-scrape-failed"
  ) null availabilityGroup.rules;
  targetCoverageRule = lib.findFirst (
    rule: rule.uid == "public-service-probe-missing"
  ) null availabilityGroup.rules;
  dashboard = builtins.fromJSON (
    builtins.readFile cfg.sys.services.grafana.provision.dashboards.service-availability
  );
  blackboxConfig = builtins.fromJSON (builtins.readFile exporter.configFile);
  publicMatrixBaseUrl = "https://matrix.${publicDomain}";
  expectedIssuer = "${publicMatrixBaseUrl}/";
  expectedFederationServer = "matrix.${publicDomain}:443";
  oidcTarget = lib.findFirst (target: target.name == "oidc-discovery") {
    expectedJsonFields = { };
  } blackbox.targets;
  federationTarget = lib.findFirst (target: target.name == "federation-discovery") {
    expectedJsonFields = { };
  } blackbox.targets;
  expectedJsonPattern =
    field: value: ''"${lib.escapeRegex field}"[[:space:]]*:[[:space:]]*"${lib.escapeRegex value}"'';
  moduleNames = map (target: "http_${target.service}_${target.name}") blackbox.targets;
in
assert blackbox.enable;
assert blackbox.targets != [ ];
assert exporter.enable;
assert exporter.listenAddress == "127.0.0.1";
assert exporter.port == blackboxConstants.port;
assert exporterUnit.serviceConfig.AmbientCapabilities == [ ];
assert exporterUnit.serviceConfig.CapabilityBoundingSet == [ ];
assert
  exporterUnit.serviceConfig.RestrictAddressFamilies == [
    "AF_INET"
    "AF_INET6"
  ];
assert
  builtins.length (builtins.attrNames blackboxConfig.modules) == builtins.length blackbox.targets;
assert builtins.length moduleNames == builtins.length (lib.unique moduleNames);
assert lib.all (moduleName: builtins.hasAttr moduleName blackboxConfig.modules) moduleNames;
assert lib.all (
  module:
  module.prober == "http"
  && module.timeout == blackboxConstants.probeTimeout
  && module.http.method == "GET"
  && module.http.follow_redirects == false
  && module.http.valid_status_codes == [ 200 ]
) (builtins.attrValues blackboxConfig.modules);
assert oidcTarget.expectedJsonFields.issuer == expectedIssuer;
assert federationTarget.expectedJsonFields."m.server" == expectedFederationServer;
assert builtins.elem (expectedJsonPattern "issuer" expectedIssuer)
  blackboxConfig.modules."http_matrix_oidc-discovery".http.fail_if_body_not_matches_regexp;
assert builtins.elem (expectedJsonPattern "m.server" expectedFederationServer)
  blackboxConfig.modules."http_matrix_federation-discovery".http.fail_if_body_not_matches_regexp;
assert scrape != null;
assert scrape.scrape_interval == blackboxConstants.scrapeInterval;
assert scrape.scrape_timeout == blackboxConstants.scrapeTimeout;
assert scrape.metrics_path == "/probe";
assert builtins.length scrape.static_configs == builtins.length blackbox.targets;
assert lib.hasPrefix "https://" (builtins.head (builtins.head scrape.static_configs).targets);
assert lib.any (relabel: relabel.target_label or null == "__param_target") scrape.relabel_configs;
assert lib.any (relabel: relabel.target_label or null == "__param_module") scrape.relabel_configs;
assert lib.any (relabel: relabel.target_label or null == "instance") scrape.relabel_configs;
assert lib.any (
  relabel: relabel.replacement or null == "127.0.0.1:${toString blackboxConstants.port}"
) scrape.relabel_configs;
assert availabilityGroup != null;
assert availabilityGroup.interval == blackboxConstants.scrapeInterval;
assert availabilityRule != null;
assert availabilityRule.for == blackboxConstants.failureWindow;
assert availabilityRule.noDataState == "Alerting";
assert lib.hasInfix "probe_success" (builtins.head availabilityRule.data).model.expr;
assert lib.hasInfix ''job="${blackboxConstants.jobName}"''
  (builtins.head availabilityRule.data).model.expr;
assert lib.hasInfix "five minutes" availabilityRule.annotations.description;
assert exporterScrapeRule != null;
assert exporterScrapeRule.noDataState == "Alerting";
assert lib.hasInfix "up" (builtins.head exporterScrapeRule.data).model.expr;
assert lib.hasInfix "absent" (builtins.head exporterScrapeRule.data).model.expr;
assert targetCoverageRule != null;
assert targetCoverageRule.noDataState == "OK";
assert lib.hasInfix "absent" (builtins.head targetCoverageRule.data).model.expr;
assert dashboard.uid == "service-availability";
assert dashboard.title == "Public Service Availability";
assert dashboard.refresh == blackboxConstants.dashboardRefresh;
assert lib.any (
  panel:
  lib.any (
    target: lib.hasInfix ''probe_success{job="${blackboxConstants.jobName}"}'' (target.expr or "")
  ) (panel.targets or [ ])
) dashboard.panels;
assert lib.any (
  panel:
  lib.any (target: lib.hasInfix "probe_ssl_earliest_cert_expiry" (target.expr or "")) (
    panel.targets or [ ]
  )
) dashboard.panels;
pkgs.runCommand "blackbox-observability-tests" { } "touch $out"
