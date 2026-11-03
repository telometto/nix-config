{ blizzard, pkgs }:
let
  inherit (pkgs) lib;
  enabledArchive = blizzard.extendModules {
    modules = [ { sys.services.securityLogArchive.enable = lib.mkForce true; } ];
  };
  groups = enabledArchive.config.services.grafana.provision.alerting.rules.settings.groups;
  group = name: (lib.findFirst (g: g.name == name) null groups).rules;
  cloudflare = group "cloudflare-alerts";
  crowdsec = group "crowdsec-health";
  blackbox = group "public-service-availability";
  archive = group "security-log-archive";
  specifications = import ../lib/security-log-archive-alerts.nix;
  findRule = uid: rules: lib.findFirst (r: r.uid == uid) null rules;
  expr = uid: (builtins.head (findRule uid cloudflare).data).model.expr;
  isPrometheus = query: query.datasourceUid == "prometheus";
  queries = lib.filter isPrometheus (
    lib.concatMap (rule: rule.data) (cloudflare ++ crowdsec ++ blackbox ++ archive)
  );
  validQuery =
    q:
    q.refId == "A"
    && q.model.refId == q.refId
    &&
      q.model.datasource == {
        type = "prometheus";
        uid = q.datasourceUid;
      }
    && q.model.instant
    && !q.model.range
    && q.model.editorMode == "code"
    && q.model.maxDataPoints == 43200
    && q.relativeTimeRange.to == 0
    && q.relativeTimeRange.from > 0;
  validThreshold =
    r:
    let
      t = builtins.elemAt r.data 1;
    in
    r.condition == "B"
    && (builtins.head r.data).refId == "A"
    && t.refId == "B"
    && t.datasourceUid == "__expr__"
    && t.model.refId == "B"
    && t.model.expression == "A"
    && t.model.type == "threshold"
    &&
      (builtins.head t.model.conditions).evaluator == {
        type = "gt";
        params = [ 0 ];
      };
  ruleTests = pkgs.writeText "grafana-cloudflare-promql-tests.json" (
    builtins.toJSON {
      rule_files = [ ];
      tests =
        map
          (scenario: {
            inherit (scenario) name input_series;
            interval = "1m";
            promql_expr_test = [
              {
                expr = expr "cf-collector-failure";
                eval_time = "10m";
                exp_samples = [
                  {
                    labels = "{}";
                    value = scenario.expected;
                  }
                ];
              }
            ];
          })
          [
            {
              name = "healthy required polls with the optional poll absent";
              input_series = [
                {
                  series = ''up{job="cloudflare"}'';
                  values = "1+0x10";
                }
                {
                  series = ''cloudflare_collector_last_success_timestamp_seconds{poll="analytics"}'';
                  values = "0+60x10";
                }
                {
                  series = ''cloudflare_collector_last_success_timestamp_seconds{poll="access"}'';
                  values = "0+60x10";
                }
              ];
              expected = 0;
            }
            {
              name = "missing collector and required metrics";
              input_series = [ ];
              expected = 1;
            }
            {
              name = "failed exporter while polls remain current";
              input_series = [
                {
                  series = ''up{job="cloudflare"}'';
                  values = "0+0x10";
                }
                {
                  series = ''cloudflare_collector_last_success_timestamp_seconds{poll="analytics"}'';
                  values = "0+60x10";
                }
                {
                  series = ''cloudflare_collector_last_success_timestamp_seconds{poll="access"}'';
                  values = "0+60x10";
                }
              ];
              expected = 1;
            }
          ];
    }
  );
in
assert lib.all validQuery queries;
assert lib.all (r: r.condition == "A" && builtins.length r.data == 1) (cloudflare ++ blackbox);
assert lib.all validThreshold (crowdsec ++ archive);
assert (findRule "cf-collector-failure" cloudflare).noDataState == "Alerting";
assert lib.all (r: r.noDataState == "OK") (
  lib.filter (r: r.uid != "cf-collector-failure") cloudflare
);
assert lib.all (
  r: r.noDataState == (if r.uid == "public-service-probe-missing" then "OK" else "Alerting")
) blackbox;
assert lib.all (r: r.noDataState == "OK") (crowdsec ++ archive);
assert lib.all (r: r.execErrState == "Error" && !r.isPaused) (
  cloudflare ++ crowdsec ++ blackbox ++ archive
);
assert lib.all (
  spec:
  let
    rule = findRule spec.uid archive;
  in
  rule.for == spec.hold
  && rule.labels.severity == spec.severity
  && (builtins.head rule.data).model.expr == "count(${spec.expr}) or vector(0)"
) specifications;
assert lib.all (r: (builtins.head r.data).queryType == "") cloudflare;
assert lib.all (r: (builtins.head r.data).model.legendFormat == "__auto") cloudflare;
assert lib.all (r: (builtins.head r.data).model.interval == "") (cloudflare ++ blackbox);
assert
  (builtins.head (findRule "crowdsec-enforcement-errors" crowdsec).data).datasourceUid
  == "security-logs";
assert
  (builtins.head (findRule "crowdsec-local-attack" crowdsec).data).datasourceUid == "security-logs";
pkgs.runCommand "grafana-alert-contracts" { nativeBuildInputs = [ pkgs.prometheus.cli ]; } ''
  promtool test rules ${ruleTests}
  touch "$out"
''
