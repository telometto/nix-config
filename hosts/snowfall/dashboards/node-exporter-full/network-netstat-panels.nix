{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Network Netstat";
      id = 274;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Netstat IP In / Out Octets
    (grafana.mkTimeseries {
      title = "Netstat IP In / Out Octets";
      id = 221;
      description = "Rate of octets sent and received at the IP layer, as reported by /proc/net/netstat";
      unit = "Bps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 163;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_netstat_IpExt_InOctets{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "IP Rx in";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_IpExt_OutOctets{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "IP Tx out";
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

    # TCP In / Out
    (grafana.mkTimeseries {
      title = "TCP In / Out";
      id = 299;
      description = "Rate of TCP segments sent and received per second, including data and control segments";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 163;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Tcp_InSegs{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "TCP Rx in";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Tcp_OutSegs{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "TCP Tx out";
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

    # UDP In / Out
    (grafana.mkTimeseries {
      title = "UDP In / Out";
      id = 55;
      description = "Rate of UDP datagrams sent and received per second, based on /proc/net/netstat";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 193;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Udp_InDatagrams{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "UDP Rx in";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Udp_OutDatagrams{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "UDP Tx out";
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

    # ICMP In / Out
    (grafana.mkTimeseries {
      title = "ICMP In / Out";
      id = 115;
      description = "Number of ICMP messages sent and received per second, including error and control messages";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 193;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Icmp_InMsgs{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "ICMP Rx in";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Icmp_OutMsgs{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "ICMP Tx out";
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

    # TCP Errors
    (grafana.mkTimeseries {
      title = "TCP Errors";
      id = 104;
      description = "Tracks various TCP error and congestion-related events, including retransmissions, timeouts, dropped connections, and buffer issues";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 203;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_netstat_TcpExt_ListenOverflows{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Listen Overflows";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_TcpExt_ListenDrops{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Listen Drops";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_TcpExt_TCPSynRetrans{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "SYN Retransmits";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Tcp_RetransSegs{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Segment Retransmits";
          refId = "D";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Tcp_InErrs{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Receive Errors";
          refId = "E";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Tcp_OutRsts{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "RST Sent";
          refId = "F";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_TcpExt_TCPRcvQDrop{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Receive Queue Drops";
          refId = "G";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_TcpExt_TCPOFOQueue{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Out-of-order Queued";
          refId = "H";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_TcpExt_TCPTimeouts{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "TCP Timeouts";
          refId = "I";
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

    # UDP Errors
    (grafana.mkTimeseries {
      title = "UDP Errors";
      id = 109;
      description = "Rate of UDP and UDPLite datagram delivery errors, including missing listeners, buffer overflows, and protocol-specific issues";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 203;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Udp_InErrors{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "UDP Rx in Errors";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Udp_NoPorts{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "UDP No Listener";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_UdpLite_InErrors{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "UDPLite Rx in Errors";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Udp_RcvbufErrors{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "UDP Rx in Buffer Errors";
          refId = "D";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Udp_SndbufErrors{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "UDP Tx out Buffer Errors";
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

    # ICMP Errors
    (grafana.mkTimeseries {
      title = "ICMP Errors";
      id = 50;
      description = "Rate of incoming ICMP messages that contained protocol-specific errors, such as bad checksums or invalid lengths";
      unit = "pps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 213;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Icmp_InErrors{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "ICMP Rx In";
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

    # TCP SynCookie
    (grafana.mkTimeseries {
      title = "TCP SynCookie";
      id = 91;
      description = "Rate of TCP SYN cookies sent, validated, and failed. These are used to protect against SYN flood attacks and manage TCP handshake resources under load";
      unit = "eps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 213;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_netstat_TcpExt_SyncookiesFailed{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "SYN Cookies Failed";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_TcpExt_SyncookiesRecv{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "SYN Cookies Validated";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_TcpExt_SyncookiesSent{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "SYN Cookies Sent";
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

    # TCP Connections
    (grafana.mkTimeseries {
      title = "TCP Connections";
      id = 85;
      description = "Number of currently established TCP connections and the system's max supported limit. On Linux, MaxConn may return -1 to indicate a dynamic/unlimited configuration";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 223;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_netstat_Tcp_CurrEstab{instance="$node",job="$job"}'';
          legendFormat = "Current Connections";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_netstat_Tcp_MaxConn{instance="$node",job="$job"}'';
          legendFormat = "Max Connections";
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

    # UDP Queue
    (grafana.mkTimeseries {
      title = "UDP Queue";
      id = 337;
      description = "Number of UDP packets currently queued in the receive (RX) and transmit (TX) buffers. A growing queue may indicate a bottleneck";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 223;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_udp_queues{instance="$node",job="$job",ip="v4",queue="rx"}'';
          legendFormat = "UDP Rx in Queue";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_udp_queues{instance="$node",job="$job",ip="v4",queue="tx"}'';
          legendFormat = "UDP Tx out Queue";
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

    # TCP Direct Transition
    (grafana.mkTimeseries {
      title = "TCP Direct Transition";
      id = 82;
      description = "Rate of TCP connection initiations per second. 'Active' opens are initiated by this host. 'Passive' opens are accepted from incoming connections";
      unit = "eps";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 233;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Tcp_ActiveOpens{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Active Opens";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_netstat_Tcp_PassiveOpens{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "Passive Opens";
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

    # TCP Stat
    (grafana.mkTimeseries {
      title = "TCP Stat";
      id = 320;
      description = "Number of TCP sockets in key connection states. Requires the --collector.tcpstat flag on node_exporter";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 233;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_tcp_connection_states{state="established",instance="$node",job="$job"}'';
          legendFormat = "Established";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_tcp_connection_states{state="fin_wait2",instance="$node",job="$job"}'';
          legendFormat = "FIN_WAIT2";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_tcp_connection_states{state="listen",instance="$node",job="$job"}'';
          legendFormat = "Listen";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_tcp_connection_states{state="time_wait",instance="$node",job="$job"}'';
          legendFormat = "TIME_WAIT";
          refId = "D";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_tcp_connection_states{state="close_wait", instance="$node", job="$job"}'';
          legendFormat = "CLOSE_WAIT";
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

  ];
}
