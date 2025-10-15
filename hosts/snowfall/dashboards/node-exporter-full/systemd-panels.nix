{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Systemd";
      id = 296;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Systemd Units State
    (grafana.mkTimeseries {
      title = "Systemd Units State";
      id = 298;
      description = "Current number of systemd units in each operational state, such as active, failed, inactive, or transitioning";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 4228;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_systemd_units{instance="$node",job="$job",state="activating"}'';
          legendFormat = "Activating";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_systemd_units{instance="$node",job="$job",state="active"}'';
          legendFormat = "Active";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_systemd_units{instance="$node",job="$job",state="deactivating"}'';
          legendFormat = "Deactivating";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_systemd_units{instance="$node",job="$job",state="failed"}'';
          legendFormat = "Failed";
          refId = "D";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_systemd_units{instance="$node",job="$job",state="inactive"}'';
          legendFormat = "Inactive";
          refId = "E";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Systemd Sockets Current
    (grafana.mkTimeseries {
      title = "Systemd Sockets Current";
      id = 331;
      description = "Current number of active connections per systemd socket, as reported by the Node Exporter systemd collector";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 4228;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_systemd_socket_current_connections{instance="$node",job="$job"}'';
          legendFormat = "{{ name }}";
          refId = "A";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Systemd Sockets Accepted
    (grafana.mkTimeseries {
      title = "Systemd Sockets Accepted";
      id = 297;
      description = "Rate of accepted connections per second for each systemd socket";
      unit = "eps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 4238;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_systemd_socket_accepted_connections_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{ name }}";
          refId = "A";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Systemd Sockets Refused
    (grafana.mkTimeseries {
      title = "Systemd Sockets Refused";
      id = 332;
      description = "Rate of systemd socket connection refusals per second, typically due to service unavailability or backlog overflow";
      unit = "eps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 4238;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_systemd_socket_refused_connections_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{ name }}";
          refId = "A";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

  ];
}
