{ lib }:

rec {
  # Helper to create common datasource reference
  prometheusDatasource = {
    type = "prometheus";
    uid = "\${ds_prometheus}";
  };

  # Default field config for gauges
  defaultGaugeFieldConfig = {
    color.mode = "thresholds";
    decimals = 1;
    mappings = [
      {
        options.match = "null";
        result.text = "N/A";
        type = "special";
      }
    ];
    max = 100;
    min = 0;
    thresholds = {
      mode = "absolute";
      steps = [
        { color = "rgba(50, 172, 45, 0.97)"; }
        {
          color = "rgba(237, 129, 40, 0.89)";
          value = 85;
        }
        {
          color = "rgba(245, 54, 54, 0.9)";
          value = 95;
        }
      ];
    };
    unit = "percent";
  };

  # Default field config for timeseries
  defaultTimeseriesFieldConfig = {
    color.mode = "palette-classic";
    custom = {
      axisBorderShow = false;
      axisCenteredZero = false;
      axisColorMode = "text";
      axisLabel = "";
      axisPlacement = "auto";
      barAlignment = 0;
      barWidthFactor = 0.6;
      drawStyle = "line";
      fillOpacity = 40;
      gradientMode = "none";
      hideFrom = {
        legend = false;
        tooltip = false;
        viz = false;
      };
      insertNulls = false;
      lineInterpolation = "linear";
      lineWidth = 1;
      pointSize = 5;
      scaleDistribution.type = "linear";
      showPoints = "never";
      spanNulls = false;
      stacking = {
        group = "A";
        mode = "none";
      };
      thresholdsStyle.mode = "off";
    };
    links = [ ];
    mappings = [ ];
    thresholds = {
      mode = "absolute";
      steps = [ { color = "green"; } ];
    };
  };

  # Create a row (section header)
  mkRow =
    {
      title,
      id,
      gridPos ? {
        h = 1;
        w = 24;
        x = 0;
        y = 0;
      },
      collapsed ? false,
    }:
    {
      inherit collapsed title id;
      inherit gridPos;
      panels = [ ];
      type = "row";
    };

  # Create a gauge panel
  mkGauge =
    {
      title,
      id,
      description,
      gridPos,
      targets,
      fieldConfig ? { },
      thresholds ? null,
      unit ? "percent",
    }:
    let
      customThresholds =
        if thresholds != null then
          thresholds
        else
          {
            mode = "absolute";
            steps = [
              { color = "rgba(50, 172, 45, 0.97)"; }
              {
                color = "rgba(237, 129, 40, 0.89)";
                value = 85;
              }
              {
                color = "rgba(245, 54, 54, 0.9)";
                value = 95;
              }
            ];
          };
    in
    {
      datasource = prometheusDatasource;
      inherit
        description
        title
        id
        gridPos
        targets
        ;
      fieldConfig = lib.recursiveUpdate {
        defaults = defaultGaugeFieldConfig // {
          inherit unit;
          thresholds = customThresholds;
        };
        overrides = [ ];
      } fieldConfig;
      options = {
        minVizHeight = 75;
        minVizWidth = 75;
        orientation = "auto";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        showThresholdLabels = false;
        showThresholdMarkers = true;
        sizing = "auto";
      };
      pluginVersion = "11.6.1";
      type = "gauge";
    };

  # Create a stat panel
  mkStat =
    {
      title,
      id,
      description ? "",
      gridPos,
      targets,
      unit ? "short",
      decimals ? 0,
      fieldConfig ? { },
    }:
    {
      datasource = prometheusDatasource;
      inherit
        description
        title
        id
        gridPos
        targets
        ;
      fieldConfig = lib.recursiveUpdate {
        defaults = {
          color.mode = "thresholds";
          inherit decimals unit;
          mappings = [
            {
              options.match = "null";
              result.text = "N/A";
              type = "special";
            }
          ];
          thresholds = {
            mode = "absolute";
            steps = [ { color = "green"; } ];
          };
        };
        overrides = [ ];
      } fieldConfig;
      maxDataPoints = 100;
      options = {
        colorMode = "none";
        graphMode = "none";
        justifyMode = "auto";
        orientation = "horizontal";
        percentChangeColorMode = "standard";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        showPercentChange = false;
        textMode = "auto";
        wideLayout = true;
      };
      pluginVersion = "11.6.1";
      type = "stat";
    };

  # Create a timeseries panel
  mkTimeseries =
    {
      title,
      id,
      description,
      gridPos,
      targets,
      fieldConfig ? { },
      options ? { },
      unit ? "short",
    }:
    {
      datasource = prometheusDatasource;
      inherit
        description
        title
        id
        gridPos
        targets
        ;
      fieldConfig = lib.recursiveUpdate {
        defaults = defaultTimeseriesFieldConfig // {
          inherit unit;
        };
        overrides = [ ];
      } fieldConfig;
      options = lib.recursiveUpdate {
        legend = {
          calcs = [ ];
          displayMode = "list";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      } options;
      pluginVersion = "11.6.1";
      type = "timeseries";
    };

  # Create a bargauge panel
  mkBargauge =
    {
      title,
      id,
      description,
      gridPos,
      targets,
      fieldConfig ? { },
    }:
    {
      datasource = prometheusDatasource;
      inherit
        description
        title
        id
        gridPos
        targets
        ;
      fieldConfig = lib.recursiveUpdate {
        defaults = {
          color.mode = "thresholds";
          decimals = 1;
          links = [ ];
          mappings = [ ];
          max = 1;
          min = 0;
          thresholds = {
            mode = "percentage";
            steps = [
              { color = "green"; }
              {
                color = "dark-yellow";
                value = 70;
              }
              {
                color = "dark-red";
                value = 90;
              }
            ];
          };
          unit = "percentunit";
        };
        overrides = [ ];
      } fieldConfig;
      options = {
        displayMode = "basic";
        legend = {
          calcs = [ ];
          displayMode = "list";
          placement = "bottom";
          showLegend = false;
        };
        maxVizHeight = 300;
        minVizHeight = 10;
        minVizWidth = 0;
        namePlacement = "auto";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        showUnfilled = true;
        sizing = "auto";
        text = { };
        valueMode = "color";
      };
      pluginVersion = "11.6.1";
      type = "bargauge";
    };

  # Helper to create a target (query)
  mkTarget =
    {
      expr,
      legendFormat ? "",
      refId,
      instant ? true,
      exemplar ? false,
    }:
    {
      editorMode = "code";
      inherit
        exemplar
        expr
        legendFormat
        refId
        instant
        ;
      format = "time_series";
      range = !instant;
      step = 240;
    };

  # Create complete dashboard structure
  mkDashboard =
    {
      title,
      uid ? null,
      panels,
      variables ? [ ],
      links ? [ ],
      tags ? [ ],
      annotations ? null,
    }:
    let
      defaultAnnotations = {
        list = [
          {
            builtIn = 1;
            datasource = {
              type = "datasource";
              uid = "grafana";
            };
            enable = true;
            hide = true;
            iconColor = "rgba(0, 211, 255, 1)";
            name = "Annotations & Alerts";
            target = {
              limit = 100;
              matchAny = false;
              tags = [ ];
              type = "dashboard";
            };
            type = "dashboard";
          }
        ];
      };
    in
    {
      __requires = [
        {
          type = "panel";
          id = "bargauge";
          name = "Bar gauge";
          version = "";
        }
        {
          type = "panel";
          id = "gauge";
          name = "Gauge";
          version = "";
        }
        {
          type = "grafana";
          id = "grafana";
          name = "Grafana";
          version = "11.6.1";
        }
        {
          type = "datasource";
          id = "prometheus";
          name = "Prometheus";
          version = "1.0.0";
        }
        {
          type = "panel";
          id = "stat";
          name = "Stat";
          version = "";
        }
        {
          type = "panel";
          id = "timeseries";
          name = "Time series";
          version = "";
        }
      ];
      annotations = if annotations != null then annotations else defaultAnnotations;
      editable = true;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      inherit
        links
        panels
        tags
        title
        ;
      templating.list = variables;
      time = {
        from = "now-24h";
        to = "now";
      };
      timepicker = { };
      timezone = "";
      refresh = "30s";
      schemaVersion = 39;
      version = 0;
    }
    // lib.optionalAttrs (uid != null) { inherit uid; };
}
