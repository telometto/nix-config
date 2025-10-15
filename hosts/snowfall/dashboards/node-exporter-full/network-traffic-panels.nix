{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Network Traffic";
      id = 272;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Network Traffic by Packets
    (grafana.mkTimeseries {
      title = "Network Traffic by Packets";
      id = 60;
      description = "Number of network packets received and transmitted per second, by interface.";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 31;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_receive_packets_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Rx in";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''rate(node_network_transmit_packets_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Tx out";
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

    # Network Traffic Errors
    (grafana.mkTimeseries {
      title = "Network Traffic Errors";
      id = 142;
      description = "Rate of packet-level errors for each network interface. Receive errors may indicate physical or driver issues; transmit errors may reflect collisions or hardware faults";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 31;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_receive_errs_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Rx in";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''rate(node_network_transmit_errs_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Tx out";
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

    # Network Traffic Drop
    (grafana.mkTimeseries {
      title = "Network Traffic Drop";
      id = 143;
      description = "Rate of dropped packets per network interface. Receive drops can indicate buffer overflow or driver issues; transmit drops may result from outbound congestion or queuing limits";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 251;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_receive_drop_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Rx in";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''rate(node_network_transmit_drop_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Tx out";
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

    # Network Traffic Compressed
    (grafana.mkTimeseries {
      title = "Network Traffic Compressed";
      id = 141;
      description = "Rate of compressed network packets received and transmitted per interface. These are common in low-bandwidth or special interfaces like PPP or SLIP";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 251;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_receive_compressed_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Rx in";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''rate(node_network_transmit_compressed_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Tx out";
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

    # Network Traffic Multicast
    (grafana.mkTimeseries {
      title = "Network Traffic Multicast";
      id = 146;
      description = "Rate of incoming multicast packets received per network interface. Multicast is used by protocols such as mDNS, SSDP, and some streaming or cluster services";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 261;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_receive_multicast_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Rx in";
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

    # Network Traffic NoHandler
    (grafana.mkTimeseries {
      title = "Network Traffic NoHandler";
      id = 327;
      description = "Rate of received packets that could not be processed due to missing protocol or handler in the kernel. May indicate unsupported traffic or misconfiguration";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 261;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_receive_nohandler_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Rx in";
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

    # Network Traffic Frame
    (grafana.mkTimeseries {
      title = "Network Traffic Frame";
      id = 145;
      description = "Rate of frame errors on received packets, typically caused by physical layer issues such as bad cables, duplex mismatches, or hardware problems";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 271;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_receive_frame_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Rx in";
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

    # Network Traffic Fifo
    (grafana.mkTimeseries {
      title = "Network Traffic Fifo";
      id = 144;
      description = "Tracks FIFO buffer overrun errors on network interfaces. These occur when incoming or outgoing packets are dropped due to queue or buffer overflows, often indicating congestion or hardware limits";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 271;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_receive_fifo_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Rx in";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''rate(node_network_transmit_fifo_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Tx out";
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

    # Network Traffic Collision
    (grafana.mkTimeseries {
      title = "Network Traffic Collision";
      id = 232;
      description = "Rate of packet collisions detected during transmission. Mostly relevant on half-duplex or legacy Ethernet networks";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 281;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_transmit_colls_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Tx out";
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

    # Network Traffic Carrier Errors
    (grafana.mkTimeseries {
      title = "Network Traffic Carrier Errors";
      id = 231;
      description = "Rate of carrier errors during transmission. These typically indicate physical layer issues like faulty cabling or duplex mismatches";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 281;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_transmit_carrier_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Tx out";
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

    # ARP Entries
    (grafana.mkTimeseries {
      title = "ARP Entries";
      id = 230;
      description = "Number of ARP entries per interface. Useful for detecting excessive ARP traffic or table growth due to scanning or misconfiguration";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 291;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_arp_entries{instance="$node",job="$job"}'';
          legendFormat = "{{ device }} ARP Table";
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

    # NF Conntrack
    (grafana.mkTimeseries {
      title = "NF Conntrack";
      id = 61;
      description = "Current and maximum connection tracking entries used by Netfilter (nf_conntrack). High usage approaching the limit may cause packet drops or connection issues";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 291;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_nf_conntrack_entries{instance="$node",job="$job"}'';
          legendFormat = "NF conntrack entries";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_nf_conntrack_entries_limit{instance="$node",job="$job"}'';
          legendFormat = "NF conntrack limit";
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

    # Network Operational Status
    (grafana.mkTimeseries {
      title = "Network Operational Status";
      id = 309;
      description = "Operational and physical link status of each network interface. Values are Yes for 'up' or link present, and No for 'down' or no carrier.\"";
      unit = "bool_yes_no";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 301;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_network_up{operstate="up",instance="$node",job="$job"}'';
          legendFormat = "{{interface}} - Operational state UP";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_network_carrier{instance="$node",job="$job"}'';
          legendFormat = "{{device}} - Physical link";
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

    # Speed
    (grafana.mkTimeseries {
      title = "Speed";
      id = 280;
      description = "Maximum speed of each network interface as reported by the operating system. This is a static hardware capability, not current throughput";
      unit = "bps";
      gridPos = {
        h = 10;
        w = 6;
        x = 12;
        y = 301;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_network_speed_bytes{instance="$node",job="$job"} * 8'';
          legendFormat = "{{ device }}";
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

    # MTU
    (grafana.mkTimeseries {
      title = "MTU";
      id = 288;
      description = "MTU (Maximum Transmission Unit) in bytes for each network interface. Affects packet size and transmission efficiency";
      unit = "none";
      gridPos = {
        h = 10;
        w = 6;
        x = 18;
        y = 301;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_network_mtu_bytes{instance="$node",job="$job"}'';
          legendFormat = "{{ device }}";
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
