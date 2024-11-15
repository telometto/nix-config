/**
 * This NixOS module configures monitoring services using Prometheus and Grafana.
 *
 * Prometheus:
 * - Enables the Prometheus service.
 * - Sets the global scrape interval to 15 seconds.
 * - Configures a scrape job named "node" to scrape the local node exporter.
 *
 * Grafana:
 * - Enables the Grafana service.
 * - Configures Grafana to listen on localhost at port 3030.
 * - Enforces the domain "monitor.zzxyz.no" and enables Gzip compression.
 * - Disables analytics reporting.
 * - Enables declarative provisioning of plugins, dashboards, and datasources.
 *   - Configures dashboards to be loaded from the specified path.
 *   - Adds two datasources:
 *     - "Prometheus" datasource pointing to the local Prometheus instance.
 *     - "Infinity" datasource for connecting to various data sources.
 *
 * Environment:
 * - Copies a Grafana dashboard JSON file to the /etc directory with the correct permissions.
 * - Includes additional system packages (currently empty).
 */
{ config, lib, pkgs, ... }:

{
  services.prometheus = {
    # Server configuration
    enable = true;

    globalConfig.scrape_interval = "15s";
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
          }
        ];
      }
    ];
  };

  services.grafana = {
    # Start base settings
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3030;
        enforce_domain = true;
        enable_gzip = true;
        domain = "monitor.zzxyz.no";
      };

      analytics.reporting_enabled = false;
    };
    # End base settings

    # Start declarative config
    declarativePlugins = with pkgs; [
      # Plugins
    ];

    provision = {
      enable = true;

      dashboards.settings.providers = [
        {
          name = "Dashboards";
          options.path = "";
        }
      ];

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
        }
        {
          name = "Infinity";
          type = "yesoreyeram-infinity-datasource";
        }
      ];
    };

  };

  environment = {
    etc = [
      {
        source = ./. + "/grafana-dashboards/some-dashboard.json";
        group = "grafana";
        user = "grafana";
      }
    ];

    systemPackages = with pkgs; [ ];
  };
  # End declarative config
}
