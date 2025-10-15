{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Memory Vmstat";
      id = 267;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Memory Pages In / Out
    (grafana.mkTimeseries {
      title = "Memory Pages In / Out";
      id = 176;
      description = "Rate of memory pages being read from or written to disk (page-in and page-out operations). High page-out may indicate memory pressure or swapping activity";
      unit = "ops";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 733;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_vmstat_pgpgin{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Pagesin - Page in ops";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_vmstat_pgpgout{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Pagesout - Page out ops";
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

    # Memory Pages Swap In / Out
    (grafana.mkTimeseries {
      title = "Memory Pages Swap In / Out";
      id = 22;
      description = "Rate at which memory pages are being swapped in from or out to disk. High swap-out activity may indicate memory pressure";
      unit = "ops";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 733;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_vmstat_pswpin{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Pswpin - Pages swapped in";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_vmstat_pswpout{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Pswpout - Pages swapped out";
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

    # Memory Page Faults
    (grafana.mkTimeseries {
      title = "Memory Page Faults";
      id = 175;
      description = "Rate of memory page faults, split into total, major (disk-backed), and derived minor (non-disk) faults. High major fault rates may indicate memory pressure or insufficient RAM";
      unit = "ops";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 913;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_vmstat_pgfault{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Pgfault - Page major and minor fault ops";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_vmstat_pgmajfault{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Pgmajfault - Major page fault ops";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_vmstat_pgfault{instance="$node",job="$job"}[$__rate_interval])  - irate(node_vmstat_pgmajfault{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Pgminfault - Minor page fault ops";
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

    # OOM Killer
    (grafana.mkTimeseries {
      title = "OOM Killer";
      id = 307;
      description = "Rate of Out-of-Memory (OOM) kill events. A non-zero value indicates the kernel has terminated one or more processes due to memory exhaustion";
      unit = "ops";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 913;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_vmstat_oom_kill{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "OOM Kills";
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
