{ pkgs, lib }:

rec {
  # Fetch dashboard from grafana.com
  fetchGrafanaDashboard =
    {
      gnetId,
      revision,
      hash,
      name ? "grafana-dashboard-${toString gnetId}-rev${toString revision}",
    }:
    pkgs.fetchurl {
      url = "https://grafana.com/api/dashboards/${toString gnetId}/revisions/${toString revision}/download";
      sha256 = hash;
      inherit name;
    };

  # Community dashboards from grafana.com
  community = {
    node-exporter-full = fetchGrafanaDashboard {
      gnetId = 1860;
      revision = 42;
      hash = "0phjy96kq4kymzggm0r51y8i2s2z2x3p69bd5nx4n10r33mjgn54";
    };

    kubernetes-cluster = fetchGrafanaDashboard {
      gnetId = 315;
      revision = 3;
      hash = "1yqqcr4ca1hglxr8kq6vrgkbv3jwargax24ciskhm5d9d1pdsipf";
    };
  };

  custom = {
    zfs-overview = ../dashboards/host/blizzard/zfs-overview.json;
    power-consumption = ../dashboards/shared/power-consumption.json;
    power-consumption-historical = ../dashboards/host/blizzard/power-consumption-historical.json;
    ups-monitoring = ../dashboards/host/blizzard/ups-monitoring.json;
  };

  all = community // custom;
}
