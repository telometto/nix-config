{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "System Processes";
      id = 312;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Processes Status
    (grafana.mkTimeseries {
      title = "Processes Status";
      id = 62;
      description = "Processes currently in runnable or blocked states. Helps identify CPU contention or I/O wait bottlenecks.";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 735;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_procs_blocked{instance="$node",job="$job"}'';
          legendFormat = "Blocked (I/O Wait)";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_procs_running{instance="$node",job="$job"}'';
          legendFormat = "Runnable (Ready for CPU)";
          refId = "B";
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

    # Processes Detailed States
    (grafana.mkTimeseries {
      title = "Processes Detailed States";
      id = 315;
      description = "Current number of processes in each state (e.g., running, sleeping, zombie). Requires --collector.processes to be enabled in node_exporter";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 735;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_processes_state{instance="$node",job="$job"}'';
          legendFormat = "{{ state }}";
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

    # Processes Forks
    (grafana.mkTimeseries {
      title = "Processes Forks";
      id = 148;
      description = "Rate of new processes being created on the system (forks/sec).";
      unit = "ops";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 765;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_forks_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Process Forks per second";
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

    # CPU Saturation per Core
    (grafana.mkTimeseries {
      title = "CPU Saturation per Core";
      id = 305;
      description = "Shows CPU saturation per core, calculated as the proportion of time spent waiting to run relative to total time demanded (running + waiting).";
      unit = "percentunit";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 765;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_schedstat_running_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "CPU {{ cpu }} - Running";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_schedstat_waiting_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "CPU {{cpu}} - Waiting Queue";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''
            irate(node_schedstat_waiting_seconds_total{instance="$node",job="$job"}[$__rate_interval])
            /
            (irate(node_schedstat_running_seconds_total{instance="$node",job="$job"}[$__rate_interval]) + irate(node_schedstat_waiting_seconds_total{instance="$node",job="$job"}[$__rate_interval]))
          '';
          legendFormat = "CPU {{cpu}}";
          refId = "C";
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

    # PIDs Number and Limit
    (grafana.mkTimeseries {
      title = "PIDs Number and Limit";
      id = 313;
      description = "Number of active PIDs on the system and the configured maximum allowed. Useful for detecting PID exhaustion risk. Requires --collector.processes in node_exporter";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 775;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_processes_pids{instance="$node",job="$job"}'';
          legendFormat = "Number of PIDs";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_processes_max_processes{instance="$node",job="$job"}'';
          legendFormat = "PIDs limit";
          refId = "B";
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

    # Threads Number and Limit
    (grafana.mkTimeseries {
      title = "Threads Number and Limit";
      id = 314;
      description = "Number of active threads on the system and the configured thread limit. Useful for monitoring thread pressure. Requires --collector.processes in node_exporter";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 775;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_processes_threads{instance="$node",job="$job"}'';
          legendFormat = "Allocated threads";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_processes_max_threads{instance="$node",job="$job"}'';
          legendFormat = "Threads limit";
          refId = "B";
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
