{ lib, grafana }:

{
  panels = [
    # Row header
    (grafana.mkRow {
      title = "Quick CPU / Mem / Disk";
      id = 261;
      gridPos = { h = 1; w = 24; x = 0; y = 0; };
    })

    # Pressure gauge (bargauge)
    (grafana.mkBargauge {
      title = "Pressure";
      id = 323;
      description = "Resource pressure via PSI";
      gridPos = { h = 4; w = 3; x = 0; y = 1; };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_pressure_cpu_waiting_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "CPU";
          refId = "A";
        })
        (grafana.mkTarget {
          expr = ''irate(node_pressure_memory_waiting_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Mem";
          refId = "B";
        })
        (grafana.mkTarget {
          expr = ''irate(node_pressure_io_waiting_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "I/O";
          refId = "C";
        })
        (grafana.mkTarget {
          expr = ''irate(node_pressure_irq_stalled_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Irq";
          refId = "D";
        })
      ];
    })

    # CPU Busy gauge
    (grafana.mkGauge {
      title = "CPU Busy";
      id = 20;
      description = "Overall CPU busy percentage (averaged across all cores)";
      gridPos = { h = 4; w = 3; x = 3; y = 1; };
      targets = [
        (grafana.mkTarget {
          expr = ''100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle", instance="$node"}[$__rate_interval])))'';
          legendFormat = "";
          refId = "A";
        })
      ];
    })

    # System Load gauge
    (grafana.mkGauge {
      title = "Sys Load";
      id = 155;
      description = "System load  over all CPU cores together";
      gridPos = { h = 4; w = 3; x = 6; y = 1; };
      targets = [
        (grafana.mkTarget {
          expr = ''scalar(node_load1{instance="$node",job="$job"}) * 100 / count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu))'';
          legendFormat = "";
          refId = "A";
        })
      ];
    })

    # RAM Used gauge
    (grafana.mkGauge {
      title = "RAM Used";
      id = 16;
      description = "Real RAM usage excluding cache and reclaimable memory";
      gridPos = { h = 4; w = 3; x = 9; y = 1; };
      targets = [
        (grafana.mkTarget {
          expr = ''clamp_min((1 - (node_memory_MemAvailable_bytes{instance="$node", job="$job"} / node_memory_MemTotal_bytes{instance="$node", job="$job"})) * 100, 0)'';
          legendFormat = "";
          refId = "B";
        })
      ];
    })

    # SWAP Used gauge
    (grafana.mkGauge {
      title = "SWAP Used";
      id = 21;
      description = "Percentage of swap space currently used by the system";
      gridPos = { h = 4; w = 3; x = 12; y = 1; };
      thresholds = {
        mode = "absolute";
        steps = [
          { color = "rgba(50, 172, 45, 0.97)"; }
          { color = "rgba(237, 129, 40, 0.89)"; value = 10; }
          { color = "rgba(245, 54, 54, 0.9)"; value = 25; }
        ];
      };
      targets = [
        (grafana.mkTarget {
          expr = ''((node_memory_SwapTotal_bytes{instance="$node",job="$job"} - node_memory_SwapFree_bytes{instance="$node",job="$job"}) / (node_memory_SwapTotal_bytes{instance="$node",job="$job"})) * 100'';
          legendFormat = "";
          refId = "A";
        })
      ];
    })

    # Root FS Used gauge
    (grafana.mkGauge {
      title = "Root FS Used";
      id = 154;
      description = "Used Root FS";
      gridPos = { h = 4; w = 3; x = 15; y = 1; };
      targets = [
        (grafana.mkTarget {
          expr = ''
            (
              (node_filesystem_size_bytes{instance="$node", job="$job", mountpoint="/", fstype!="rootfs"}
               - node_filesystem_avail_bytes{instance="$node", job="$job", mountpoint="/", fstype!="rootfs"})
              / node_filesystem_size_bytes{instance="$node", job="$job", mountpoint="/", fstype!="rootfs"}
            ) * 100
          '';
          legendFormat = "";
          refId = "A";
        })
      ];
    })

    # CPU Cores stat
    (grafana.mkStat {
      title = "CPU Cores";
      id = 14;
      description = "";
      gridPos = { h = 2; w = 2; x = 18; y = 1; };
      targets = [
        (grafana.mkTarget {
          expr = ''count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu))'';
          legendFormat = "__auto";
          refId = "A";
        })
      ];
    })

    # RAM Total stat
    (grafana.mkStat {
      title = "RAM Total";
      id = 75;
      description = "";
      unit = "bytes";
      decimals = 0;
      gridPos = { h = 2; w = 2; x = 20; y = 1; };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_MemTotal_bytes{instance="$node",job="$job"}'';
          legendFormat = "";
          refId = "A";
        })
      ];
    })

    # SWAP Total stat
    (grafana.mkStat {
      title = "SWAP Total";
      id = 18;
      description = "";
      unit = "bytes";
      decimals = 0;
      gridPos = { h = 2; w = 2; x = 22; y = 1; };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_SwapTotal_bytes{instance="$node",job="$job"}'';
          legendFormat = "";
          refId = "A";
        })
      ];
    })

    # RootFS Total stat
    (grafana.mkStat {
      title = "RootFS Total";
      id = 23;
      description = "";
      unit = "bytes";
      decimals = 0;
      gridPos = { h = 2; w = 2; x = 18; y = 3; };
      targets = [
        (grafana.mkTarget {
          expr = ''node_filesystem_size_bytes{instance="$node",job="$job",mountpoint="/",fstype!="rootfs"}'';
          legendFormat = "";
          refId = "A";
        })
      ];
    })

    # Uptime stat
    (grafana.mkStat {
      title = "Uptime";
      id = 15;
      description = "";
      unit = "s";
      decimals = 1;
      gridPos = { h = 2; w = 4; x = 20; y = 3; };
      targets = [
        (grafana.mkTarget {
          expr = ''node_time_seconds{instance="$node",job="$job"} - node_boot_time_seconds{instance="$node",job="$job"}'';
          legendFormat = "";
          refId = "A";
        })
      ];
    })
  ];
}
