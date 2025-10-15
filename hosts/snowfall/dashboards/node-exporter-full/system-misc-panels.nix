{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "System Misc";
      id = 269;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Context Switches / Interrupts
    (grafana.mkTimeseries {
      title = "Context Switches / Interrupts";
      id = 8;
      description = "Per-second rate of context switches and hardware interrupts. High values may indicate intense CPU or I/O activity";
      unit = "ops";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 816;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_context_switches_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Context switches";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_intr_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Interrupts";
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

    # System Load
    (grafana.mkTimeseries {
      title = "System Load";
      id = 7;
      description = "System load average over 1, 5, and 15 minutes. Reflects the number of active or waiting processes. Values above CPU core count may indicate overload";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 816;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_load1{instance="$node",job="$job"}'';
          legendFormat = "Load 1m";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_load5{instance="$node",job="$job"}'';
          legendFormat = "Load 5m";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_load15{instance="$node",job="$job"}'';
          legendFormat = "Load 15m";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu))'';
          legendFormat = "CPU Core Count";
          refId = "D";
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

    # CPU Frequency Scaling
    (grafana.mkTimeseries {
      title = "CPU Frequency Scaling";
      id = 321;
      description = "Real-time CPU frequency scaling per core, including average minimum and maximum allowed scaling frequencies";
      unit = "hertz";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 826;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_cpu_scaling_frequency_hertz{instance="$node",job="$job"}'';
          legendFormat = "CPU {{ cpu }}";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''avg(node_cpu_scaling_frequency_max_hertz{instance="$node",job="$job"})'';
          legendFormat = "Max";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''avg(node_cpu_scaling_frequency_min_hertz{instance="$node",job="$job"})'';
          legendFormat = "Min";
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

    # CPU Schedule Timeslices
    (grafana.mkTimeseries {
      title = "CPU Schedule Timeslices";
      id = 306;
      description = "Rate of scheduling timeslices executed per CPU. Reflects how frequently the scheduler switches tasks on each core";
      unit = "ops";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 826;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_schedstat_timeslices_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "CPU {{ cpu }}";
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

    # IRQ Detail
    (grafana.mkTimeseries {
      title = "IRQ Detail";
      id = 259;
      description = "Breaks down hardware interrupts by type and device. Useful for diagnosing IRQ load on network, disk, or CPU interfaces. Requires --collector.interrupts to be enabled in node_exporter";
      unit = "ops";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 836;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_interrupts_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{ type }} - {{ info }}";
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

    # Entropy
    (grafana.mkTimeseries {
      title = "Entropy";
      id = 151;
      description = "Number of bits of entropy currently available to the system's random number generators (e.g., /dev/random). Low values may indicate that random number generation could block or degrade performance of cryptographic operations";
      unit = "decbits";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 836;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_entropy_available_bits{instance="$node",job="$job"}'';
          legendFormat = "Entropy available";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_entropy_pool_size_bits{instance="$node",job="$job"}'';
          legendFormat = "Entropy pool max";
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
