{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Node Exporter";
      id = 279;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Node Exporter Scrape Time
    (grafana.mkTimeseries {
      title = "Node Exporter Scrape Time";
      id = 40;
      description = "Duration of each individual collector executed during a Node Exporter scrape. Useful for identifying slow or failing collectors";
      unit = "s";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 164;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_scrape_collector_duration_seconds{instance="$node",job="$job"}'';
          legendFormat = "{{collector}}";
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

    # Exporter Process CPU Usage
    (grafana.mkTimeseries {
      title = "Exporter Process CPU Usage";
      id = 308;
      description = "Rate of CPU time used by the process exposing this metric (user + system mode)";
      unit = "percentunit";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 164;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(process_cpu_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Process CPU Usage";
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

    # Exporter Processes Memory
    (grafana.mkTimeseries {
      title = "Exporter Processes Memory";
      id = 149;
      description = "Tracks the memory usage of the process exposing this metric (e.g., node_exporter), including current virtual memory and maximum virtual memory limit";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 10;
        x = 0;
        y = 174;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''process_virtual_memory_bytes{instance="$node",job="$job"}'';
          legendFormat = "Virtual Memory";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''process_virtual_memory_max_bytes{instance="$node",job="$job"}'';
          legendFormat = "Virtual Memory Limit";
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

    # Exporter File Descriptor Usage
    (grafana.mkTimeseries {
      title = "Exporter File Descriptor Usage";
      id = 64;
      description = "Number of file descriptors used by the exporter process versus its configured limit";
      unit = "short";
      gridPos = {
        h = 10;
        w = 10;
        x = 10;
        y = 174;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''process_max_fds{instance="$node",job="$job"}'';
          legendFormat = "Maximum open file descriptors";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''process_open_fds{instance="$node",job="$job"}'';
          legendFormat = "Open file descriptors";
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

    # Node Exporter Scrape
    (grafana.mkTimeseries {
      title = "Node Exporter Scrape";
      id = 157;
      description = "Shows whether each Node Exporter collector scraped successfully (1 = success, 0 = failure), and whether the textfile collector returned an error.";
      unit = "bool";
      gridPos = {
        h = 10;
        w = 4;
        x = 20;
        y = 174;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_scrape_collector_success{instance="$node",job="$job"}'';
          legendFormat = "{{collector}}";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''1 - node_textfile_scrape_error{instance="$node",job="$job"}'';
          legendFormat = "textfile";
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
