{ lib, pkgs }:

let
  grafana = import ../../../../lib/grafana.nix { inherit lib; };

  # Import panel modules
  quickOverview = import ./quick-overview.nix { inherit lib grafana; };
  basicPanels = import ./basic-panels.nix { inherit lib grafana; };
  cpuPanels = import ./cpu-panels.nix { inherit lib grafana; };
  memoryPanels = import ./memory-panels.nix { inherit lib grafana; };

  # Dashboard variables for datasource and node selection
  variables = [
    {
      current = { };
      includeAll = false;
      label = "Datasource";
      name = "ds_prometheus";
      options = [ ];
      query = "prometheus";
      refresh = 1;
      regex = "";
      type = "datasource";
    }
    {
      current = { };
      datasource = {
        type = "prometheus";
        uid = "\${ds_prometheus}";
      };
      definition = "";
      includeAll = false;
      label = "Job";
      name = "job";
      options = [ ];
      query = {
        query = "label_values(node_uname_info, job)";
        refId = "Prometheus-job-Variable-Query";
      };
      refresh = 1;
      regex = "";
      sort = 1;
      type = "query";
    }
    {
      current = { };
      datasource = {
        type = "prometheus";
        uid = "\${ds_prometheus}";
      };
      definition = "label_values(node_uname_info{job=\"\$job\"}, nodename)";
      includeAll = false;
      label = "Nodename";
      name = "nodename";
      options = [ ];
      query = {
        query = "label_values(node_uname_info{job=\"\$job\"}, nodename)";
        refId = "Prometheus-nodename-Variable-Query";
      };
      refresh = 1;
      regex = "";
      sort = 1;
      type = "query";
    }
    {
      current = { };
      datasource = {
        type = "prometheus";
        uid = "\${ds_prometheus}";
      };
      definition = "label_values(node_uname_info{job=\"\$job\", nodename=\"\$nodename\"}, instance)";
      includeAll = false;
      label = "Instance";
      name = "node";
      options = [ ];
      query = {
        query = "label_values(node_uname_info{job=\"\$job\", nodename=\"\$nodename\"}, instance)";
        refId = "Prometheus-node-Variable-Query";
      };
      refresh = 1;
      regex = "";
      sort = 1;
      type = "query";
    }
  ];

  # Dashboard links
  links = [
    {
      icon = "external link";
      tags = [ ];
      targetBlank = true;
      title = "GitHub";
      type = "link";
      url = "https://github.com/rfmoz/grafana-dashboards";
    }
    {
      icon = "external link";
      tags = [ ];
      targetBlank = true;
      title = "Grafana";
      type = "link";
      url = "https://grafana.com/grafana/dashboards/1860";
    }
  ];

  # Combine all panels
  allPanels = lib.flatten [
    quickOverview.panels
    basicPanels.panels
    cpuPanels.panels
    memoryPanels.panels
  ];

in
grafana.mkDashboard {
  title = "Node Exporter Full";
  uid = "rYdddlPWk";
  tags = [ "linux" ];
  panels = allPanels;
  inherit variables links;
}
