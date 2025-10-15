{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Storage Filesystem";
      id = 271;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # File Descriptor
    (grafana.mkTimeseries {
      title = "File Descriptor";
      id = 28;
      description = "Number of file descriptors currently allocated system-wide versus the system limit. Important for detecting descriptor exhaustion risks";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 30;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_filefd_maximum{instance="$node",job="$job"}'';
          legendFormat = "Max open files";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_filefd_allocated{instance="$node",job="$job"}'';
          legendFormat = "Open files";
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

    # File Nodes Free
    (grafana.mkTimeseries {
      title = "File Nodes Free";
      id = 41;
      description = "Number of free file nodes (inodes) available per mounted filesystem. A low count may prevent file creation even if disk space is available";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 30;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_filesystem_files_free{instance="$node",job="$job",device!~'rootfs'}'';
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
        };
      };
    })

    # Filesystem in ReadOnly / Error
    (grafana.mkTimeseries {
      title = "Filesystem in ReadOnly / Error";
      id = 44;
      description = "Indicates filesystems mounted in read-only mode or reporting device-level I/O errors.";
      unit = "bool_yes_no";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 370;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_filesystem_readonly{instance="$node",job="$job",device!~'rootfs'}'';
          legendFormat = "{{mountpoint}} - ReadOnly";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_filesystem_device_error{instance="$node",job="$job",device!~'rootfs',fstype!~'tmpfs'}'';
          legendFormat = "{{mountpoint}} - Device error";
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

    # File Nodes Size
    (grafana.mkTimeseries {
      title = "File Nodes Size";
      id = 219;
      description = "Number of file nodes (inodes) available per mounted filesystem. Reflects maximum file capacity regardless of disk size";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 370;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_filesystem_files{instance="$node",job="$job",device!~'rootfs'}'';
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
        };
      };
    })

  ];
}
