{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default to save space
    (grafana.mkRow {
      title = "CPU";
      id = 265;
      collapsed = true;
      gridPos = { h = 1; w = 24; x = 0; y = 20; };
    })

    # Detailed CPU panel with all modes
    (grafana.mkTimeseries {
      title = "CPU";
      id = 3;
      description = "CPU time usage split by state, normalized across all CPU cores";
      unit = "percentunit";
      gridPos = { h = 12; w = 12; x = 0; y = 21; };
      targets = [
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{mode="system",instance="$node",job="$job"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "System - Processes executing in kernel mode";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{mode="user",instance="$node",job="$job"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "User - Normal processes executing in user mode";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{mode="nice",instance="$node",job="$job"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Nice - Niced processes executing in user mode";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{mode="iowait",instance="$node",job="$job"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Iowait - Waiting for I/O to complete";
          refId = "D";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{mode="irq",instance="$node",job="$job"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Irq - Servicing interrupts";
          refId = "E";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{mode="softirq",instance="$node",job="$job"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Softirq - Servicing softirqs";
          refId = "F";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{mode="steal",instance="$node",job="$job"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Steal - Time spent in other operating systems when running in a virtualized environment";
          refId = "G";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum(irate(node_cpu_seconds_total{mode="idle",instance="$node",job="$job"}[$__rate_interval])) / scalar(count(count(node_cpu_seconds_total{instance="$node",job="$job"}) by (cpu)))'';
          legendFormat = "Idle - Waiting for something to happen";
          refId = "H";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''sum by(instance) (irate(node_cpu_guest_seconds_total{instance="$node",job="$job"}[$__rate_interval])) / on(instance) group_left sum by (instance)((irate(node_cpu_seconds_total{instance="$node",job="$job"}[$__rate_interval]))) > 0'';
          legendFormat = "Guest CPU usage";
          refId = "I";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = ["min" "mean" "max"];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
          width = 250;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "desc";
        };
      };
      fieldConfig = {
        defaults = {
          custom = {
            lineInterpolation = "smooth";
            lineWidth = 2;
            fillOpacity = 70;
            stacking = { group = "A"; mode = "percent"; };
          };
          min = 0;
        };
        overrides = [
          {
            matcher = { id = "byName"; options = "Idle - Waiting for something to happen"; };
            properties = [{ id = "color"; value = { fixedColor = "#052B51"; mode = "fixed"; }; }];
          }
          {
            matcher = { id = "byName"; options = "Iowait - Waiting for I/O to complete"; };
            properties = [{ id = "color"; value = { fixedColor = "#EAB839"; mode = "fixed"; }; }];
          }
          {
            matcher = { id = "byName"; options = "Irq - Servicing interrupts"; };
            properties = [{ id = "color"; value = { fixedColor = "#BF1B00"; mode = "fixed"; }; }];
          }
          {
            matcher = { id = "byName"; options = "Nice - Niced processes executing in user mode"; };
            properties = [{ id = "color"; value = { fixedColor = "#C15C17"; mode = "fixed"; }; }];
          }
          {
            matcher = { id = "byName"; options = "Softirq - Servicing softirqs"; };
            properties = [{ id = "color"; value = { fixedColor = "#E24D42"; mode = "fixed"; }; }];
          }
          {
            matcher = { id = "byName"; options = "Steal - Time spent in other operating systems when running in a virtualized environment"; };
            properties = [{ id = "color"; value = { fixedColor = "#FCE2DE"; mode = "fixed"; }; }];
          }
          {
            matcher = { id = "byName"; options = "System - Processes executing in kernel mode"; };
            properties = [{ id = "color"; value = { fixedColor = "#508642"; mode = "fixed"; }; }];
          }
          {
            matcher = { id = "byName"; options = "User - Normal processes executing in user mode"; };
            properties = [{ id = "color"; value = { fixedColor = "#5195CE"; mode = "fixed"; }; }];
          }
          {
            matcher = { id = "byName"; options = "Guest CPU usage"; };
            properties = [
              { id = "custom.fillOpacity"; value = 0; }
              { id = "custom.lineStyle"; value = { dash = [10 10]; fill = "dash"; }; }
              { id = "custom.stacking"; value = { group = "A"; mode = "none"; }; }
            ];
          }
        ];
      };
    })
  ];
}
