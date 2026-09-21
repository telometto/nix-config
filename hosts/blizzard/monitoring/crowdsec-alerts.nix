let
  threshold = {
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
  };
  rule = uid: title: expr: description: {
    inherit uid title;
    condition = "B";
    for = "5m";
    noDataState = "OK";
    execErrState = "Error";
    isPaused = false;
    labels = {
      service = "crowdsec";
      severity = "warning";
    };
    annotations = {
      summary = title;
      inherit description;
    };
    data = [
      {
        refId = "A";
        queryType = "";
        relativeTimeRange = {
          from = 600;
          to = 0;
        };
        datasourceUid = "prometheus";
        model = {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          refId = "A";
          expr = "count(${expr}) or vector(0)";
          instant = true;
          range = false;
          editorMode = "code";
          intervalMs = 60000;
          maxDataPoints = 43200;
        };
      }
      threshold
    ];
  };
in
{
  services.grafana.provision.alerting.rules.settings.groups = [
    {
      orgId = 1;
      name = "crowdsec-health";
      folder = "Security";
      interval = "1m";
      rules = [
        (
          let
            base =
              rule "crowdsec-enforcement-errors" "CrowdSec is denying requests due to operational failures" "0"
                "Inspect Traefik and the local API. These denials are not counted as prevented attacks.";
          in
          base
          // {
            data = [
              {
                refId = "A";
                datasourceUid = "security-logs";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  refId = "A";
                  datasource = {
                    type = "victoriametrics-logs-datasource";
                    uid = "security-logs";
                  };
                  queryType = "stats";
                  expr = "_stream:{service=\"crowdsec\"} | unpack_json | filter kind:=\"enforcement_error\" | stats count() failures";
                };
              }
              threshold
            ];
          }
        )
        (rule "crowdsec-unavailable" "CrowdSec metrics unavailable"
          ''up{job=~"crowdsec|crowdsec-firewall|security-logs|security-alloy"} == 0 or absent(up{job="crowdsec"}) or absent(up{job="crowdsec-firewall"}) or absent(up{job="security-logs"}) or absent(up{job="security-alloy"})''
          "A detector, bouncer or security-log collector cannot be scraped. Check the failed job on Blizzard."
        )
        (rule "crowdsec-ingestion-stalled" "CrowdSec HTTP ingestion stalled"
          ''(sum(increase(cs_journalctlsource_hits_total{job="crowdsec",acquis_type="traefik"}[10m])) or vector(0)) == 0 and sum(increase(traefik_entrypoint_requests_total{job="traefik"}[10m])) > 20''
          "Traefik is handling requests but CrowdSec has read no HTTP logs for ten minutes."
        )
        (rule "crowdsec-parsing-failed" "CrowdSec parsing failure rate elevated"
          ''sum(rate(cs_parser_hits_ko_total{job="crowdsec"}[10m])) / clamp_min(sum(rate(cs_parser_hits_total{job="crowdsec"}[10m])), 0.001) > 0.05''
          "Over 5% of input lines fail parsing. Review the acquisition and installed parser; a few application diagnostics are expected."
        )
        (rule "crowdsec-bouncer-stale" "Traefik stopped fetching CrowdSec decisions"
          ''(sum(increase(cs_lapi_bouncer_requests_total{job="crowdsec",bouncer="traefik-bouncer",route="/v1/decisions/stream"}[10m])) or vector(0)) == 0''
          "No Traefik decision-stream requests in ten minutes. Check authentication and plugin startup."
        )
        (rule "crowdsec-alert-archive-failed" "CrowdSec alert archive failed"
          ''node_systemd_unit_state{name="crowdsec-alert-archive.service",state="failed"} == 1''
          "The local alert archive timer failed. Inspect the service journal before retained engine alerts expire."
        )
        (rule "crowdsec-hub-check-failed" "CrowdSec rules need maintenance"
          ''node_systemd_unit_state{name="crowdsec-update-hub.service",state="failed"} == 1''
          "Installed rules have updates, or the catalogue check failed. Inspect crowdsec-update-hub.service and follow the reviewed upgrade runbook. Rules were not automatically upgraded."
        )
        (rule "crowdsec-appsec-stalled" "CrowdSec AppSec inspection stalled"
          ''(sum(increase(cs_appsec_reqs_total{job="crowdsec"}[10m])) or vector(0)) == 0 and sum(increase(traefik_entrypoint_requests_total{job="traefik"}[10m])) > 20''
          "Traefik is busy but AppSec has inspected no requests for ten minutes. Observation mode fails open on connection errors; check its loopback listener and bouncer authentication."
        )
        (
          let
            base =
              rule "crowdsec-local-attack" "CrowdSec detected exploitation or repeated authentication attacks" "0"
                "Inspect the CrowdSec investigation dashboard. AppSec matches are observations, not blocked requests; simulated DoS detections are excluded.";
          in
          base
          // {
            for = "0s";
            data = [
              {
                refId = "A";
                datasourceUid = "security-logs";
                relativeTimeRange = {
                  from = 600;
                  to = 0;
                };
                model = {
                  refId = "A";
                  datasource = {
                    type = "victoriametrics-logs-datasource";
                    uid = "security-logs";
                  };
                  queryType = "stats";
                  expr = ''_stream:{service="crowdsec"} | unpack_json | filter (kind:="appsec_observation" or (kind:="local_detection" and simulated:="false" and scenario:~"(?i)(bf|bruteforce|cve|sqli|xss|backdoor|log4j|spring4shell)")) | stats count() detections'';
                };
              }
              threshold
            ];
          }
        )
        (rule "crowdsec-log-storage-full" "Security log storage cannot accept writes"
          ''vl_storage_is_read_only{job="security-logs"} == 1''
          "VictoriaLogs has entered read-only mode. Free disk space and verify ingestion recovery."
        )
        (rule "crowdsec-log-delivery-failed" "Security log delivery is dropping records"
          ''sum(increase(loki_write_dropped_entries_total{job="security-alloy"}[10m])) > 0''
          "Alloy dropped security records after delivery failures. Inspect VictoriaLogs availability and the local WAL."
        )
      ];
    }
  ];
}
