{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "System Timesync";
      id = 293;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Time Synchronized Drift
    (grafana.mkTimeseries {
      title = "Time Synchronized Drift";
      id = 260;
      description = "Tracks the system clock's estimated and maximum error, as well as its offset from the reference clock (e.g., via NTP). Useful for detecting synchronization drift";
      unit = "s";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 734;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_timex_estimated_error_seconds{instance="$node",job="$job"}'';
          legendFormat = "Estimated error";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_timex_offset_seconds{instance="$node",job="$job"}'';
          legendFormat = "Offset local vs reference";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_timex_maxerror_seconds{instance="$node",job="$job"}'';
          legendFormat = "Maximum error";
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

    # Time PLL Adjust
    (grafana.mkTimeseries {
      title = "Time PLL Adjust";
      id = 291;
      description = "NTP phase-locked loop (PLL) time constant used by the kernel to control time adjustments. Lower values mean faster correction but less stability";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 734;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_timex_loop_time_constant{instance="$node",job="$job"}'';
          legendFormat = "PLL Time Constant";
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

    # Time Synchronized Status
    (grafana.mkTimeseries {
      title = "Time Synchronized Status";
      id = 168;
      description = "Shows whether the system clock is synchronized to a reliable time source, and the current frequency correction ratio applied by the kernel to maintain synchronization";
      unit = "short";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 884;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_timex_sync_status{instance="$node",job="$job"}'';
          legendFormat = "Sync status (1 = ok)";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_timex_frequency_adjustment_ratio{instance="$node",job="$job"}'';
          legendFormat = "Frequency Adjustment";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_timex_tick_seconds{instance="$node",job="$job"}'';
          legendFormat = "Tick Interval";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_timex_tai_offset_seconds{instance="$node",job="$job"}'';
          legendFormat = "TAI Offset";
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

    # PPS Frequency / Stability
    (grafana.mkTimeseries {
      title = "PPS Frequency / Stability";
      id = 333;
      description = "Displays the PPS signal's frequency offset and stability (jitter) in hertz. Useful for monitoring high-precision time sources like GPS or atomic clocks";
      unit = "rothz";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 884;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_timex_pps_frequency_hertz{instance="$node",job="$job"}'';
          legendFormat = "PPS Frequency Offset";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_timex_pps_stability_hertz{instance="$node",job="$job"}'';
          legendFormat = "PPS Frequency Stability";
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

    # PPS Time Accuracy
    (grafana.mkTimeseries {
      title = "PPS Time Accuracy";
      id = 334;
      description = "Tracks PPS signal timing jitter and shift compared to system clock";
      unit = "s";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 894;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_timex_pps_jitter_seconds{instance="$node",job="$job"}'';
          legendFormat = "PPS Jitter";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_timex_pps_shift_seconds{instance="$node",job="$job"}'';
          legendFormat = "PPS Shift";
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

    # PPS Sync Events
    (grafana.mkTimeseries {
      title = "PPS Sync Events";
      id = 335;
      description = "Rate of PPS synchronization diagnostics including calibration events, jitter violations, errors, and frequency stability exceedances";
      unit = "ops";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 894;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''irate(node_timex_pps_calibration_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "PPS Calibrations/sec";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_timex_pps_error_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "PPS Errors/sec";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_timex_pps_stability_exceeded_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "PPS Stability Exceeded/sec";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''irate(node_timex_pps_jitter_total{instance="$node",job="$job"}[$__rate_interval])'';
          legendFormat = "PPS Jitter Events/sec";
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

  ];
}
