{ lib, pkgs }:

let
  grafana = import ../../../../lib/grafana.nix { inherit lib; };

  # Import panel modules
  quickOverview = import ./quick-overview.nix { inherit lib grafana; };
  basicPanels = import ./basic-panels.nix { inherit lib grafana; };
  combinedDetailedPanels = import ./combined-detailed-panels.nix { inherit lib grafana; };
  cpuPanels = import ./cpu-panels.nix { inherit lib grafana; };
  memoryPanels = import ./memory-panels.nix { inherit lib grafana; };
  memoryMeminfoPanels = import ./memory-meminfo-panels.nix { inherit lib grafana; };
  memoryVmstatPanels = import ./memory-vmstat-panels.nix { inherit lib grafana; };
  systemTimesyncPanels = import ./system-timesync-panels.nix { inherit lib grafana; };
  systemProcessesPanels = import ./system-processes-panels.nix { inherit lib grafana; };
  systemMiscPanels = import ./system-misc-panels.nix { inherit lib grafana; };
  hardwareMiscPanels = import ./hardware-misc-panels.nix { inherit lib grafana; };
  systemdPanels = import ./systemd-panels.nix { inherit lib grafana; };
  storageDiskPanels = import ./storage-disk-panels.nix { inherit lib grafana; };
  storageFilesystemPanels = import ./storage-filesystem-panels.nix { inherit lib grafana; };
  networkTrafficPanels = import ./network-traffic-panels.nix { inherit lib grafana; };
  networkSockstatPanels = import ./network-sockstat-panels.nix { inherit lib grafana; };
  networkNetstatPanels = import ./network-netstat-panels.nix { inherit lib grafana; };
  nodeExporterPanels = import ./node-exporter-panels.nix { inherit lib grafana; };

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
    combinedDetailedPanels.panels
    cpuPanels.panels
    memoryPanels.panels
    memoryMeminfoPanels.panels
    memoryVmstatPanels.panels
    systemTimesyncPanels.panels
    systemProcessesPanels.panels
    systemMiscPanels.panels
    hardwareMiscPanels.panels
    systemdPanels.panels
    storageDiskPanels.panels
    storageFilesystemPanels.panels
    networkTrafficPanels.panels
    networkSockstatPanels.panels
    networkNetstatPanels.panels
    nodeExporterPanels.panels
  ];

in
grafana.mkDashboard {
  title = "Node Exporter Full";
  uid = "rYdddlPWk";
  tags = [ "linux" ];
  panels = allPanels;
  inherit variables links;
}
