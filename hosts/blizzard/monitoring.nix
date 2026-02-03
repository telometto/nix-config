{
  lib,
  config,
  VARS,
  ...
}:
{
  sys.services = {
    prometheusExporters = {
      node = {
        enableRapl = true;
        port = 11011;
      };

      zfs = {
        enable = true;
        port = 11013;
        pools = [
          "rpool"
          "tank"
        ];
      };
    };

    electricityPriceExporter = {
      enable = true;
      port = 11012;
      priceArea = "NO2";
    };

    victoriametrics = {
      enable = true;

      listenAddress = "0.0.0.0";
      openFirewall = true;

      retentionPeriod = "1y";

      prometheusRemoteWrite.enable = true;

      dedup = {
        enable = true;
        minScrapeInterval = "1ms";
      };

      grafanaDatasource = {
        enable = true;
        name = "VictoriaMetrics (Long-term)";
      };
    };

    prometheus = {
      enable = true;
      port = 11009;

      listenAddress = "127.0.0.1";
      openFirewall = false;
      scrapeInterval = "5s";

      extraScrapeConfigs = [
        {
          job_name = "traefik";
          static_configs = [
            {
              targets = [ "localhost:8080" ];
            }
          ];
        }
        {
          job_name = "zfs";
          static_configs = [
            {
              targets = [ "localhost:${toString config.sys.services.prometheusExporters.zfs.port}" ];
            }
          ];
        }
        {
          job_name = "kubelet-metrics";
          scheme = "http";
          static_configs = [
            {
              targets = [ "127.0.0.1:10255" ];
            }
          ];
        }
        {
          job_name = "cadvisor-metrics";
          scheme = "http";
          metrics_path = "/metrics/cadvisor";
          static_configs = [
            {
              targets = [ "127.0.0.1:10255" ];
            }
          ];
        }
        {
          job_name = "kube-state-metrics";
          scheme = "http";
          static_configs = [
            {
              targets = [ "127.0.0.1:32080" ];
            }
          ];
        }
        {
          job_name = "electricity-price";
          scrape_interval = "5m";
          static_configs = [
            {
              targets = [ "localhost:${toString config.sys.services.electricityPriceExporter.port}" ];
            }
          ];
        }
        {
          job_name = "ups";
          metrics_path = "/ups_metrics";
          static_configs = [
            {
              targets = lib.mapAttrsToList (name: _: name) config.sys.services.ups.devices;
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "ups";
            }
            {
              target_label = "__address__";
              replacement = "localhost:${toString config.sys.services.ups.prometheusExporter.port}";
            }
          ];
        }
      ];
    };

    grafana = {
      enable = true;
      port = 11010;

      addr = "127.0.0.1";
      openFirewall = false;
      domain = "metrics.${VARS.domains.public}";

      provision.dashboards =
        let
          grafanaDashboards = import ../../lib/grafana-dashboards.nix {
            inherit lib;
            inherit (config.nixpkgs) pkgs;
          };
        in
        {
          "kubernetes-cluster" = grafanaDashboards.community.kubernetes-cluster;
          "zfs-overview" = grafanaDashboards.custom.zfs-overview;
          "power-consumption" = grafanaDashboards.custom.power-consumption;
          "power-consumption-historical" = grafanaDashboards.custom.power-consumption-historical;
          "ups-monitoring" = grafanaDashboards.custom.ups-monitoring;
          "electricity-prices" = grafanaDashboards.custom.electricity-prices;
        };

      reverseProxy = {
        enable = true;
        domain = "metrics.${VARS.domains.public}";
        cfTunnel.enable = true;
      };
    };
  };
}
