{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Memory";
      id = 267;
      collapsed = true;
      gridPos = { h = 1; w = 24; x = 0; y = 21; };
    })

    # Detailed Memory panel
    (grafana.mkTimeseries {
      title = "Memory";
      id = 24;
      description = "Breakdown of physical memory and swap usage. Hardware-detected memory errors are also displayed";
      unit = "bytes";
      gridPos = { h = 12; w = 12; x = 12; y = 21; };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_MemTotal_bytes{instance="$node",job="$job"}'';
          legendFormat = "Total RAM";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_MemFree_bytes{instance="$node",job="$job"}'';
          legendFormat = "Free RAM";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Cached_bytes{instance="$node",job="$job"}'';
          legendFormat = "Cached";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Buffers_bytes{instance="$node",job="$job"}'';
          legendFormat = "Buffers";
          refId = "D";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_MemTotal_bytes{instance="$node",job="$job"} - node_memory_MemFree_bytes{instance="$node",job="$job"} - node_memory_Buffers_bytes{instance="$node",job="$job"} - node_memory_Cached_bytes{instance="$node",job="$job"} - node_memory_Slab_bytes{instance="$node",job="$job"} - node_memory_PageTables_bytes{instance="$node",job="$job"} - node_memory_VmallocUsed_bytes{instance="$node",job="$job"}'';
          legendFormat = "Used RAM";
          refId = "E";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_SwapTotal_bytes{instance="$node",job="$job"}'';
          legendFormat = "Total Swap";
          refId = "F";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_SwapTotal_bytes{instance="$node",job="$job"} - node_memory_SwapFree_bytes{instance="$node",job="$job"}'';
          legendFormat = "Used Swap";
          refId = "G";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = ["min" "mean" "max"];
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
          custom = {
            stacking = { group = "A"; mode = "none"; };
            fillOpacity = 20;
          };
          min = 0;
        };
        overrides = [
          {
            matcher = { id = "byName"; options = "Total RAM"; };
            properties = [
              { id = "color"; value = { fixedColor = "#E0F9D7"; mode = "fixed"; }; }
              { id = "custom.fillOpacity"; value = 0; }
              { id = "custom.lineWidth"; value = 2; }
            ];
          }
          {
            matcher = { id = "byName"; options = "Used RAM"; };
            properties = [{ id = "color"; value = { fixedColor = "#7EB26D"; mode = "fixed"; }; }];
          }
          {
            matcher = { id = "byName"; options = "Total Swap"; };
            properties = [
              { id = "color"; value = { fixedColor = "#E24D42"; mode = "fixed"; }; }
              { id = "custom.fillOpacity"; value = 0; }
              { id = "custom.lineWidth"; value = 2; }
            ];
          }
          {
            matcher = { id = "byName"; options = "Used Swap"; };
            properties = [{ id = "color"; value = { fixedColor = "#E24D42"; mode = "fixed"; }; }];
          }
        ];
      };
    })

    # Memory Available
    (grafana.mkTimeseries {
      title = "Memory Available";
      id = 138;
      description = "Amount of memory available for starting new applications, without swapping";
      unit = "bytes";
      gridPos = { h = 12; w = 12; x = 0; y = 33; };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_MemAvailable_bytes{instance="$node",job="$job"}'';
          legendFormat = "MemAvailable";
          refId = "A";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = ["min" "mean" "max"];
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
          min = 0;
          custom.fillOpacity = 20;
        };
      };
    })
  ];
}
