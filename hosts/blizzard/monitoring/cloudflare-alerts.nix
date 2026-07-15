let
  prometheusDatasource = {
    type = "prometheus";
    uid = "prometheus";
  };

  mkPrometheusRule =
    {
      uid,
      title,
      expr,
      summary,
      description,
      severity ? "warning",
      from ? 600,
      pendingFor ? "0s",
      noDataState ? "OK",
    }:
    {
      inherit uid title noDataState;
      condition = "A";
      execErrState = "Error";
      for = pendingFor;
      isPaused = false;

      data = [
        {
          refId = "A";
          queryType = "";
          relativeTimeRange = {
            inherit from;
            to = 0;
          };
          datasourceUid = prometheusDatasource.uid;
          model = {
            datasource = prometheusDatasource;
            editorMode = "code";
            inherit expr;
            instant = true;
            interval = "";
            intervalMs = 60000;
            legendFormat = "__auto";
            maxDataPoints = 43200;
            range = false;
            refId = "A";
          };
        }
      ];

      annotations = {
        inherit summary description;
      };
      labels = {
        inherit severity;
        service = "cloudflare";
      };
    };
in
{
  # Grafana-managed alerts intentionally use the stable local Prometheus UID.
  # The dashboard uses VictoriaMetrics for long-term queries, but that
  # datasource deliberately has no stable UID on Blizzard.
  services.grafana.provision.alerting.rules.settings = {
    apiVersion = 1;
    groups = [
      {
        orgId = 1;
        name = "cloudflare-alerts";
        folder = "Cloudflare";
        interval = "1m";
        rules = [
          (mkPrometheusRule {
            uid = "cf-unexpected-access-login";
            title = "Cloudflare unexpected Access login";
            severity = "critical";
            from = 300;
            expr = ''
              cloudflare_access_last_authentication_timestamp_seconds{decision="allowed", owner="false", principal!="service-token"} > time() - 300
            '';
            summary = "Unexpected Cloudflare Access login: {{ $labels.principal }} to {{ $labels.app }}";
            description = "Cloudflare Access allowed {{ $labels.principal }} into {{ $labels.app }} at {{ humanizeTimestamp $values.A.Value }}. Verify that this login was expected.";
          })

          (mkPrometheusRule {
            uid = "cf-repeated-access-denials";
            title = "Cloudflare repeated Access denials";
            expr = ''
              sum by (app, principal) (
                (
                  cloudflare_access_authentications_total{decision="denied"}
                  unless cloudflare_access_authentications_total{decision="denied"} offset 10m
                )
                or increase(cloudflare_access_authentications_total{decision="denied"}[10m])
              ) >= 5
            '';
            summary = "Repeated Cloudflare Access denials for {{ $labels.principal }} on {{ $labels.app }}";
            description = "Cloudflare Access denied {{ $labels.principal }} at least five times for {{ $labels.app }} in ten minutes (observed {{ $values.A.Value }} denials).";
          })

          (mkPrometheusRule {
            uid = "cf-security-action-burst";
            title = "Cloudflare security-action burst";
            expr = ''
              sum by (zone, host) (
                (
                  cloudflare_http_security_actions_total{action!~"allow|skip|unknown"}
                  unless cloudflare_http_security_actions_total{action!~"allow|skip|unknown"} offset 10m
                )
                or increase(cloudflare_http_security_actions_total{action!~"allow|skip|unknown"}[10m])
              ) >= 25
            '';
            summary = "Cloudflare enforcement burst on {{ $labels.host }}";
            description = "Cloudflare recorded at least 25 enforcement actions for {{ $labels.host }} in zone {{ $labels.zone }} over ten minutes (observed {{ $values.A.Value }} actions).";
          })

          (mkPrometheusRule {
            uid = "cf-origin-failure-anomaly";
            title = "Cloudflare origin failure anomaly";
            pendingFor = "5m";
            expr = ''
              (
                sum by (zone, host) (
                  (
                    cloudflare_http_requests_total{status=~"5.."}
                    unless cloudflare_http_requests_total{status=~"5.."} offset 10m
                  )
                  or increase(cloudflare_http_requests_total{status=~"5.."}[10m])
                )
                /
                sum by (zone, host) (
                  (
                    cloudflare_http_requests_total
                    unless cloudflare_http_requests_total offset 10m
                  )
                  or increase(cloudflare_http_requests_total[10m])
                )
              ) > 0.05
              and on (zone, host)
              sum by (zone, host) (
                (
                  cloudflare_http_requests_total
                  unless cloudflare_http_requests_total offset 10m
                )
                or increase(cloudflare_http_requests_total[10m])
              ) >= 20
            '';
            summary = "Elevated Cloudflare 5xx ratio on {{ $labels.host }}";
            description = "More than 5% of requests to {{ $labels.host }} in zone {{ $labels.zone }} returned 5xx responses for at least five minutes. Current ten-minute ratio: {{ humanizePercentage $values.A.Value }}.";
          })

          (mkPrometheusRule {
            uid = "cf-collector-failure";
            title = "Cloudflare metrics collector failure";
            from = 900;
            noDataState = "Alerting";
            expr = ''
              (
                (
                  (min(up{job="cloudflare"}) < bool 1)
                  or absent(up{job="cloudflare"})
                )
                +
                (
                  (time() - min(cloudflare_collector_last_success_timestamp_seconds{poll=~"analytics|access"}) > bool 900)
                  or absent(cloudflare_collector_last_success_timestamp_seconds{poll=~"analytics|access"})
                )
              ) > bool 0
            '';
            summary = "Cloudflare metrics collection is unhealthy";
            description = "The Cloudflare Prometheus target is down, missing, or has not completed a successful API poll for at least 15 minutes. Check cloudflare-metrics.service and its API errors.";
          })

          (mkPrometheusRule {
            uid = "cf-history-gap";
            title = "Cloudflare unrecoverable history gap";
            from = 300;
            noDataState = "Alerting";
            expr = ''
              (max(cloudflare_collector_state_gap) > bool 0)
              or absent(cloudflare_collector_state_gap)
            '';
            summary = "Cloudflare metrics contain an unrecoverable history gap";
            description = "Collector state is outside Cloudflare's available analytics window, or the gap metric is missing. The affected interval cannot be reconstructed and should be investigated.";
          })
        ];
      }
    ];
  };
}
