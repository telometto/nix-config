{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Network Sockstat";
      id = 273;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Sockstat TCP
    (grafana.mkTimeseries {
      title = "Sockstat TCP";
      id = 63;
      description = "Tracks TCP socket usage and memory per node";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 32;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_sockstat_TCP_alloc{instance="$node",job="$job"}'';
          legendFormat = "Allocated Sockets";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_sockstat_TCP_inuse{instance="$node",job="$job"}'';
          legendFormat = "In-Use Sockets";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_sockstat_TCP_orphan{instance="$node",job="$job"}'';
          legendFormat = "Orphaned Sockets";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_sockstat_TCP_tw{instance="$node",job="$job"}'';
          legendFormat = "TIME_WAIT Sockets";
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

    # Sockstat UDP
    (grafana.mkTimeseries {
      title = "Sockstat UDP";
      id = 124;
      description = "Number of UDP and UDPLite sockets currently in use";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 32;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_sockstat_UDPLITE_inuse{instance="$node",job="$job"}'';
          legendFormat = "UDPLite - In-Use Sockets";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_sockstat_UDP_inuse{instance="$node",job="$job"}'';
          legendFormat = "UDP - In-Use Sockets";
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

    # Sockstat Used
    (grafana.mkTimeseries {
      title = "Sockstat Used";
      id = 126;
      description = "Total number of sockets currently in use across all protocols (TCP, UDP, UNIX, etc.), as reported by /proc/net/sockstat";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 42;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_sockstat_sockets_used{instance="$node",job="$job"}'';
          legendFormat = "Total sockets";
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

    # Sockstat FRAG / RAW
    (grafana.mkTimeseries {
      title = "Sockstat FRAG / RAW";
      id = 125;
      description = "Number of FRAG and RAW sockets currently in use. RAW sockets are used for custom protocols or tools like ping; FRAG sockets are used internally for IP packet defragmentation";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 42;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_sockstat_FRAG_inuse{instance="$node",job="$job"}'';
          legendFormat = "FRAG - In-Use Sockets";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_sockstat_RAW_inuse{instance="$node",job="$job"}'';
          legendFormat = "RAW - In-Use Sockets";
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

    # Sockstat Memory Size
    (grafana.mkTimeseries {
      title = "Sockstat Memory Size";
      id = 220;
      description = "Kernel memory used by TCP, UDP, and IP fragmentation buffers";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 52;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_sockstat_TCP_mem_bytes{instance="$node",job="$job"}'';
          legendFormat = "TCP";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_sockstat_UDP_mem_bytes{instance="$node",job="$job"}'';
          legendFormat = "UDP";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_sockstat_FRAG_memory{instance="$node",job="$job"}'';
          legendFormat = "Fragmentation";
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

    # Sockstat Average Socket Memory
    (grafana.mkTimeseries {
      title = "Sockstat Average Socket Memory";
      id = 339;
      description = "Average memory used per socket (TCP/UDP). Helps tune net.ipv4.tcp_rmem / tcp_wmem";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 52;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_sockstat_TCP_mem_bytes{instance="$node",job="$job"} / node_sockstat_TCP_inuse{instance="$node",job="$job"}'';
          legendFormat = "TCP";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_sockstat_UDP_mem_bytes{instance="$node",job="$job"} / node_sockstat_UDP_inuse{instance="$node",job="$job"}'';
          legendFormat = "UDP";
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

    # TCP/UDP Kernel Buffer Memory Pages
    (grafana.mkTimeseries {
      title = "TCP/UDP Kernel Buffer Memory Pages";
      id = 336;
      description = "TCP/UDP socket memory usage in kernel (in pages)";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 62;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_sockstat_TCP_mem{instance="$node",job="$job"}'';
          legendFormat = "TCP";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_sockstat_UDP_mem{instance="$node",job="$job"}'';
          legendFormat = "UDP";
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

    # Softnet Packets
    (grafana.mkTimeseries {
      title = "Softnet Packets";
      id = 290;
      description = "Packets processed and dropped by the softnet network stack per CPU. Drops may indicate CPU saturation or network driver limitations";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 62;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_softnet_processed_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "CPU {{cpu}} - Processed";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_softnet_dropped_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "CPU {{cpu}} - Dropped";
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

    # Softnet Out of Quota
    (grafana.mkTimeseries {
      title = "Softnet Out of Quota";
      id = 310;
      description = "How often the kernel was unable to process all packets in the softnet queue before time ran out. Frequent squeezes may indicate CPU contention or driver inefficiency";
      unit = "eps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 72;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_softnet_times_squeezed_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "CPU {{cpu}} - Times Squeezed";
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

    # Softnet RPS
    (grafana.mkTimeseries {
      title = "Softnet RPS";
      id = 330;
      description = "Tracks the number of packets processed or dropped by Receive Packet Steering (RPS), a mechanism to distribute packet processing across CPUs";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 72;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_softnet_received_rps_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "CPU {{cpu}} - Processed";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_softnet_flow_limit_count_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "CPU {{cpu}} - Dropped";
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
