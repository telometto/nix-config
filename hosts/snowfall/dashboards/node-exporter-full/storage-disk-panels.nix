{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Storage Disk";
      id = 270;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Disk Read/Write IOps
    (grafana.mkTimeseries {
      title = "Disk Read/Write IOps";
      id = 9;
      description = "Number of I/O operations completed per second for the device (after merges), including both reads and writes";
      unit = "iops";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 29;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_reads_completed_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Read";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_disk_writes_completed_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Write";
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

    # Disk Read/Write Data
    (grafana.mkTimeseries {
      title = "Disk Read/Write Data";
      id = 33;
      description = "Number of bytes read from or written to the device per second";
      unit = "Bps";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 29;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_read_bytes_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Read";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_disk_written_bytes_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Write";
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

    # Disk Average Wait Time
    (grafana.mkTimeseries {
      title = "Disk Average Wait Time";
      id = 37;
      description = "Average time for requests issued to the device to be served. This includes the time spent by the requests in queue and the time spent servicing them.";
      unit = "s";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 389;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_read_time_seconds_total{instance="$node",job="$job"}[$__rate_interval]) / irate(node_disk_reads_completed_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Read";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_disk_write_time_seconds_total{instance="$node",job="$job"}[$__rate_interval]) / irate(node_disk_writes_completed_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Write";
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

    # Average Queue Size
    (grafana.mkTimeseries {
      title = "Average Queue Size";
      id = 35;
      description = "Average queue length of the requests that were issued to the device";
      unit = "none";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 389;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_io_time_weighted_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
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
        };
      };
    })

    # Disk R/W Merged
    (grafana.mkTimeseries {
      title = "Disk R/W Merged";
      id = 133;
      description = "Number of read and write requests merged per second that were queued to the device";
      unit = "iops";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 399;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_reads_merged_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Read";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_disk_writes_merged_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Write";
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

    # Time Spent Doing I/Os
    (grafana.mkTimeseries {
      title = "Time Spent Doing I/Os";
      id = 36;
      description = "Percentage of time the disk spent actively processing I/O operations, including general I/O, discards (TRIM), and write cache flushes";
      unit = "percentunit";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 399;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_io_time_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - General IO";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_disk_discard_time_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Discard/TRIM";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_disk_flush_requests_time_seconds_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Flush (write cache)";
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

    # Disk Ops Discards / Flush
    (grafana.mkTimeseries {
      title = "Disk Ops Discards / Flush";
      id = 301;
      description = "Per-second rate of discard (TRIM) and flush (write cache) operations. Useful for monitoring low-level disk activity on SSDs and advanced storage";
      unit = "ops";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 409;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_discards_completed_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Discards completed";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_disk_discards_merged_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Discards merged";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_disk_flush_requests_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "{{device}} - Flush";
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

    # Disk Sectors Discarded Successfully
    (grafana.mkTimeseries {
      title = "Disk Sectors Discarded Successfully";
      id = 326;
      description = "Shows how many disk sectors are discarded (TRIMed) per second. Useful for monitoring SSD behavior and storage efficiency";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 409;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_disk_discarded_sectors_total{instance="$node",job="$job"}[$__rate_interval])'';
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
        };
      };
    })

    # Instantaneous Queue Size
    (grafana.mkTimeseries {
      title = "Instantaneous Queue Size";
      id = 34;
      description = "Number of in-progress I/O requests at the time of sampling (active requests in the disk queue)";
      unit = "none";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 419;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_disk_io_now{instance="$node",job="$job"}'';
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
        };
      };
    })

  ];
}
