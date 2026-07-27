{
  lib,
  pkgs,
  VARS,
  ...
}:
let
  grafanaDashboards = import ../../../lib/grafana-dashboards.nix { inherit lib pkgs; };
in
{
  sys.services.grafana = {
    enable = true;

    port = 11010;
    addr = "127.0.0.1";
    openFirewall = false;
    domain = "metrics.${VARS.domains.public}";

    provision.dashboards = {
      "arr-services" = grafanaDashboards.custom.arr-services;
      "cloudflare-overview" = grafanaDashboards.custom.cloudflare-overview;
      "kubernetes-cluster" = grafanaDashboards.community.kubernetes-cluster;
      "zfs-overview" = grafanaDashboards.custom.zfs-overview;
      "power-consumption" = grafanaDashboards.custom.power-consumption;
      "power-consumption-historical" = grafanaDashboards.custom.power-consumption-historical;
      "ups-monitoring" = grafanaDashboards.custom.ups-monitoring;
      "electricity-prices" = grafanaDashboards.custom.electricity-prices;
    };

    reverseProxy = {
      enable = true;
      domain = "metrics.${VARS.domains.public}";
      middlewares = [ "app-compat-headers" ];
      cfTunnel.enable = true;
    };
  };

  sys.services.grafanaPushover = {
    enable = true;
    # Cloudflare alert summaries intentionally include the normalized login
    # email so unexpected users can be identified from the notification.
    messageTemplate = ''
      {{- if eq (index .CommonLabels "service") "cloudflare" -}}
      {{- if gt (len .Alerts.Firing) 0 }}
      FIRING ({{ len .Alerts.Firing }})
      {{- range .Alerts.Firing }}
      - {{ .Annotations.summary }}
      {{- end }}
      {{- end }}
      {{- if gt (len .Alerts.Resolved) 0 }}
      RESOLVED ({{ len .Alerts.Resolved }})
      {{- range .Alerts.Resolved }}
      - {{ .Annotations.summary }}
      {{- end }}
      {{- end }}
      {{- else -}}
      {{ template "default.message" . }}
      {{- end -}}
    '';
  };
}
