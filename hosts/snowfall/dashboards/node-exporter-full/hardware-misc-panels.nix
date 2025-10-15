{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Hardware Misc";
      id = 304;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Hardware Temperature Monitor
    (grafana.mkTimeseries {
      title = "Hardware Temperature Monitor";
      id = 158;
      description = "Monitors hardware sensor temperatures and critical thresholds as exposed by Linux hwmon. Includes CPU, GPU, and motherboard sensors where available";
      unit = "celsius";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 737;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_hwmon_temp_celsius{instance="$node",job="$job"} * on(chip) group_left(chip_name) node_hwmon_chip_names{instance="$node",job="$job"}'';
          legendFormat = "{{ chip_name }} {{ sensor }}";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_hwmon_temp_crit_alarm_celsius{instance="$node",job="$job"} * on(chip) group_left(chip_name) node_hwmon_chip_names{instance="$node",job="$job"}'';
          legendFormat = "{{ chip_name }} {{ sensor }} Critical Alarm";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_hwmon_temp_crit_celsius{instance="$node",job="$job"} * on(chip) group_left(chip_name) node_hwmon_chip_names{instance="$node",job="$job"}'';
          legendFormat = "{{ chip_name }} {{ sensor }} Critical";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_hwmon_temp_crit_hyst_celsius{instance="$node",job="$job"} * on(chip) group_left(chip_name) node_hwmon_chip_names{instance="$node",job="$job"}'';
          legendFormat = "{{ chip_name }} {{ sensor }} Critical Historical";
          refId = "D";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_hwmon_temp_max_celsius{instance="$node",job="$job"} * on(chip) group_left(chip_name) node_hwmon_chip_names{instance="$node",job="$job"}'';
          legendFormat = "{{ chip_name }} {{ sensor }} Max";
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

    # Cooling Device Utilization
    (grafana.mkTimeseries {
      title = "Cooling Device Utilization";
      id = 300;
      description = "Shows how hard each cooling device (fan/throttle) is working relative to its maximum capacity";
      unit = "percent";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 737;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''100 * node_cooling_device_cur_state{instance="$node",job="$job"} / node_cooling_device_max_state{instance="$node",job="$job"}'';
          legendFormat = "{{ name }} - {{ type }} ";
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

    # Power Supply
    (grafana.mkTimeseries {
      title = "Power Supply";
      id = 302;
      description = "Shows the online status of power supplies (e.g., AC, battery). A value of 1-Yes indicates the power supply is active/online";
      unit = "bool_yes_no";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 747;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_power_supply_online{instance="$node",job="$job"}'';
          legendFormat = "{{ power_supply }} online";
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

    # Hardware Fan Speed
    (grafana.mkTimeseries {
      title = "Hardware Fan Speed";
      id = 325;
      description = "Displays the current fan speeds (RPM) from hardware sensors via the hwmon interface";
      unit = "rotrpm";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 747;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_hwmon_fan_rpm{instance="$node",job="$job"} * on(chip) group_left(chip_name) node_hwmon_chip_names{instance="$node",job="$job"}'';
          legendFormat = "{{ chip_name }} {{ sensor }}";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_hwmon_fan_min_rpm{instance="$node",job="$job"} * on(chip) group_left(chip_name) node_hwmon_chip_names{instance="$node",job="$job"}'';
          legendFormat = "{{ chip_name }} {{ sensor }} rpm min";
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
