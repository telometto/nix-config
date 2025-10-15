{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "CPU / Memory / Net / Disk";
      id = 265;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 20;
      };
    })

    # Network Traffic detailed
    (grafana.mkTimeseries {
      title = "Network Traffic";
      id = 84;
      description = "Detailed network traffic per interface showing received and transmitted bytes";
      unit = "Bps";
      gridPos = {
        h = 12;
        w = 12;
        x = 0;
        y = 433;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_network_receive_bytes_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Rx {{device}}";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_network_transmit_bytes_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Tx {{device}}";
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
        };
        overrides = [
          {
            matcher = {
              id = "byRegexp";
              options = "/.*Tx.*/";
            };
            properties = [
              {
                id = "custom.transform";
                value = "negative-Y";
              }
            ];
          }
        ];
      };
    })

    # Network Saturation
    (grafana.mkTimeseries {
      title = "Network Saturation";
      id = 338;
      description = "Network interface saturation (dropped packets and errors)";
      unit = "pps";
      gridPos = {
        h = 12;
        w = 12;
        x = 12;
        y = 433;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_network_receive_drop_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Rx drop {{device}}";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_network_transmit_drop_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Tx drop {{device}}";
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
        };
        overrides = [
          {
            matcher = {
              id = "byRegexp";
              options = "/.*Tx.*/";
            };
            properties = [
              {
                id = "custom.transform";
                value = "negative-Y";
              }
            ];
          }
        ];
      };
    })

    # Disk IOps
    (grafana.mkTimeseries {
      title = "Disk IOps";
      id = 229;
      description = "Disk I/O operations per second for each device";
      unit = "iops";
      gridPos = {
        h = 12;
        w = 12;
        x = 0;
        y = 445;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_reads_completed_total{instance="$node",job="$job",device=~"[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+"}[$__rate_interval])'';
          legendFormat = "Read {{device}}";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_disk_writes_completed_total{instance="$node",job="$job",device=~"[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+"}[$__rate_interval])'';
          legendFormat = "Write {{device}}";
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
          mode = "single";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
        };
        overrides = [
          {
            matcher = {
              id = "byRegexp";
              options = "/.*Read.*/";
            };
            properties = [
              {
                id = "custom.transform";
                value = "negative-Y";
              }
            ];
          }
        ];
      };
    })

    # Disk Throughput
    (grafana.mkTimeseries {
      title = "Disk Throughput";
      id = 42;
      description = "Disk read and write throughput in bytes per second";
      unit = "Bps";
      gridPos = {
        h = 12;
        w = 12;
        x = 12;
        y = 445;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_read_bytes_total{instance="$node",job="$job",device=~"[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+"}[$__rate_interval])'';
          legendFormat = "Read {{device}}";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_disk_written_bytes_total{instance="$node",job="$job",device=~"[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+"}[$__rate_interval])'';
          legendFormat = "Write {{device}}";
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
          mode = "single";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
        };
        overrides = [
          {
            matcher = {
              id = "byRegexp";
              options = "/.*Read.*/";
            };
            properties = [
              {
                id = "custom.transform";
                value = "negative-Y";
              }
            ];
          }
        ];
      };
    })

    # Filesystem Space Available
    (grafana.mkTimeseries {
      title = "Filesystem Space Available";
      id = 43;
      description = "Available space on each mounted filesystem";
      unit = "bytes";
      gridPos = {
        h = 12;
        w = 12;
        x = 0;
        y = 457;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_filesystem_avail_bytes{instance="$node",job="$job",device!="tmpfs",fstype!="tmpfs"}'';
          legendFormat = "{{mountpoint}}";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_filesystem_size_bytes{instance="$node",job="$job",device!="tmpfs",fstype!="tmpfs"}'';
          legendFormat = "Total {{mountpoint}}";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_filesystem_size_bytes{instance="$node",job="$job",device!="tmpfs",fstype!="tmpfs"} - node_filesystem_avail_bytes{instance="$node",job="$job",device!="tmpfs",fstype!="tmpfs"}'';
          legendFormat = "Used {{mountpoint}}";
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
        overrides = [
          {
            matcher = {
              id = "byRegexp";
              options = "/^Total.*/";
            };
            properties = [
              {
                id = "custom.fillOpacity";
                value = 0;
              }
              {
                id = "custom.lineStyle";
                value = {
                  dash = [
                    10
                    10
                  ];
                  fill = "dash";
                };
              }
            ];
          }
        ];
      };
    })

    # Filesystem Used
    (grafana.mkTimeseries {
      title = "Filesystem Used";
      id = 156;
      description = "Percentage of filesystem space used";
      unit = "percentunit";
      gridPos = {
        h = 12;
        w = 12;
        x = 12;
        y = 457;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''(node_filesystem_size_bytes{instance="$node",job="$job",device!="tmpfs",fstype!="tmpfs"} - node_filesystem_avail_bytes{instance="$node",job="$job",device!="tmpfs",fstype!="tmpfs"}) / node_filesystem_size_bytes{instance="$node",job="$job",device!="tmpfs",fstype!="tmpfs"}'';
          legendFormat = "{{mountpoint}}";
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
          max = 1;
        };
      };
    })

    # Disk I/O Utilization
    (grafana.mkTimeseries {
      title = "Disk I/O Utilization";
      id = 127;
      description = "Percentage of time the disk was busy processing I/O requests";
      unit = "percentunit";
      gridPos = {
        h = 12;
        w = 12;
        x = 0;
        y = 469;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_io_time_seconds_total{instance="$node",job="$job",device=~"[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+"}[$__rate_interval])'';
          legendFormat = "{{device}}";
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
          max = 1;
        };
      };
    })

    # Pressure Stall Information
    (grafana.mkTimeseries {
      title = "Pressure Stall Information";
      id = 322;
      description = "PSI metrics showing resource contention (CPU, memory, I/O)";
      unit = "percentunit";
      gridPos = {
        h = 12;
        w = 12;
        x = 12;
        y = 469;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_pressure_cpu_waiting_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "CPU some";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_pressure_memory_waiting_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Memory some";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_pressure_memory_stalled_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Memory full";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_pressure_io_waiting_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "I/O some";
          refId = "D";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_pressure_io_stalled_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "I/O full";
          refId = "E";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_pressure_irq_stalled_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "IRQ full";
          refId = "F";
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
