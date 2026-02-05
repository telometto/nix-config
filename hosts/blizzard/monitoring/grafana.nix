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
      cfTunnel.enable = true;
    };
  };
}
