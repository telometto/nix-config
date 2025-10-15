{ lib, grafana }:

{
  panels = [
    # Row header
    (grafana.mkRow {
      title = "Basic CPU / Mem / Net / Disk";
      id = 263;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 5;
      };
    })

    # CPU Basic timeseries
    (grafana.mkTimeseries {
      title = "CPU Basic";
      id = 77;
      description = "CPU time spent busy vs idle, split by activity type";
      unit = "percentunit";
      gridPos = {
        h = 7;
        w = 12;
        x = 0;
        y = 6;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{instance="$node",job="$job", mode="system"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Busy System";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{instance="$node",job="$job", mode="user"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Busy User";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{instance="$node",job="$job", mode="iowait"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Busy Iowait";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{instance="$node",job="$job", mode=~".*irq"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Busy IRQs";
          refId = "D";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{instance="$node",job="$job",  mode!='idle',mode!='user',mode!='system',mode!='iowait',mode!='irq',mode!='softirq'}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Busy Other";
          refId = "E";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{instance="$node",job="$job", mode="idle"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Idle";
          refId = "F";
          instant = false;
        })
      ];
      fieldConfig = {
        overrides = [
          {
            matcher = {
              id = "byName";
              options = "Busy Iowait";
            };
            properties = [
              {
                id = "color";
                value = {
                  fixedColor = "#890F02";
                  mode = "fixed";
                };
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "Idle";
            };
            properties = [
              {
                id = "color";
                value = {
                  fixedColor = "#052B51";
                  mode = "fixed";
                };
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "Busy System";
            };
            properties = [
              {
                id = "color";
                value = {
                  fixedColor = "#EAB839";
                  mode = "fixed";
                };
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "Busy User";
            };
            properties = [
              {
                id = "color";
                value = {
                  fixedColor = "#0A437C";
                  mode = "fixed";
                };
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "Busy Other";
            };
            properties = [
              {
                id = "color";
                value = {
                  fixedColor = "#6D1F62";
                  mode = "fixed";
                };
              }
            ];
          }
        ];
        defaults = {
          custom = {
            lineInterpolation = "smooth";
            stacking = {
              group = "A";
              mode = "percent";
            };
          };
        };
      };
    })

    # Memory Basic timeseries
    (grafana.mkTimeseries {
      title = "Memory Basic";
      id = 78;
      description = "RAM and swap usage overview, including caches";
      unit = "bytes";
      gridPos = {
        h = 7;
        w = 12;
        x = 12;
        y = 6;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_MemTotal_bytes{instance="$node",job="$job"}'';
          legendFormat = "Total";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_MemTotal_bytes{instance="$node",job="$job"} - node_memory_MemFree_bytes{instance="$node",job="$job"} - (node_memory_Cached_bytes{instance="$node",job="$job"} + node_memory_Buffers_bytes{instance="$node",job="$job"} + node_memory_SReclaimable_bytes{instance="$node",job="$job"})'';
          legendFormat = "Used";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Cached_bytes{instance="$node",job="$job"} + node_memory_Buffers_bytes{instance="$node",job="$job"} + node_memory_SReclaimable_bytes{instance="$node",job="$job"}'';
          legendFormat = "Cache + Buffer";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_MemFree_bytes{instance="$node",job="$job"}'';
          legendFormat = "Free";
          refId = "D";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''(node_memory_SwapTotal_bytes{instance="$node",job="$job"} - node_memory_SwapFree_bytes{instance="$node",job="$job"})'';
          legendFormat = "Swap used";
          refId = "E";
          instant = false;
        })
      ];
      fieldConfig = {
        defaults.custom.stacking = {
          group = "A";
          mode = "normal";
        };
        overrides = [
          {
            matcher = {
              id = "byName";
              options = "Swap used";
            };
            properties = [
              {
                id = "color";
                value = {
                  fixedColor = "#BF1B00";
                  mode = "fixed";
                };
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "Total";
            };
            properties = [
              {
                id = "color";
                value = {
                  fixedColor = "#E0F9D7";
                  mode = "fixed";
                };
              }
              {
                id = "custom.fillOpacity";
                value = 0;
              }
              {
                id = "custom.stacking";
                value = {
                  group = false;
                  mode = "normal";
                };
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "Cache + Buffer";
            };
            properties = [
              {
                id = "color";
                value = {
                  fixedColor = "#052B51";
                  mode = "fixed";
                };
              }
            ];
          }
          {
            matcher = {
              id = "byName";
              options = "Free";
            };
            properties = [
              {
                id = "color";
                value = {
                  fixedColor = "#7EB26D";
                  mode = "fixed";
                };
              }
            ];
          }
        ];
      };
    })

    # Network Traffic Basic
    (grafana.mkTimeseries {
      title = "Network Traffic Basic";
      id = 74;
      description = "Per-interface network traffic (receive and transmit) in bits per second";
      unit = "bps";
      gridPos = {
        h = 7;
        w = 12;
        x = 0;
        y = 13;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''rate(node_network_receive_bytes_total{instance="$node",job="$job"}[$__rate_interval])*8'';
          legendFormat = "Rx {{device}}";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''rate(node_network_transmit_bytes_total{instance="$node",job="$job"}[$__rate_interval])*8'';
          legendFormat = "Tx {{device}} ";
          refId = "B";
          instant = false;
        })
      ];
      fieldConfig = {
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

    # Disk Space Used Basic
    (grafana.mkTimeseries {
      title = "Disk Space Used Basic";
      id = 152;
      description = "Percentage of filesystem space used for each mounted device";
      unit = "percent";
      gridPos = {
        h = 7;
        w = 12;
        x = 12;
        y = 13;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''((node_filesystem_size_bytes{instance="$node", job="$job", device!~"rootfs"} - node_filesystem_avail_bytes{instance="$node", job="$job", device!~"rootfs"}) / node_filesystem_size_bytes{instance="$node", job="$job", device!~"rootfs"}) * 100'';
          legendFormat = "{{mountpoint}}";
          refId = "A";
          instant = false;
        })
      ];
      fieldConfig = {
        defaults = {
          max = 100;
          min = 0;
        };
      };
    })
  ];
}
