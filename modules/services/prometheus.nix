{ lib, config, ... }:
let
  cfg = config.sys.services.prometheus;
in
{
  options.sys.services.prometheus = {
    enable = lib.mkEnableOption "Prometheus monitoring system";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "Port on which Prometheus listens";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which Prometheus listens";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for Prometheus port";
    };

    scrapeInterval = lib.mkOption {
      type = lib.types.str;
      default = "10s";
      description = "Default scrape interval for all scrape jobs";
    };

    retentionTime = lib.mkOption {
      type = lib.types.str;
      default = "15d";
      description = "How long to retain samples in storage";
    };

    extraScrapeConfigs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Additional scrape configurations beyond the auto-generated ones";
      example = lib.literalExpression ''
        [
          {
            job_name = "myapp";
            static_configs = [{
              targets = [ "localhost:8080" ];
            }];
          }
        ]
      '';
    };

    webExternalUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The URL under which Prometheus is externally reachable.
        Used when Prometheus is behind a reverse proxy with a subpath.
      '';
      example = "https://example.com/prometheus/";
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Prometheus.";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/prometheus";
        description = "URL path prefix for Prometheus.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Prometheus.";
      };

      extraMiddlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional Traefik middlewares to apply.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = lib.mkDefault true;
      inherit (cfg) port listenAddress retentionTime;

      webExternalUrl = lib.mkIf (cfg.webExternalUrl != null) cfg.webExternalUrl;

      globalConfig = {
        scrape_interval = cfg.scrapeInterval;
      };

      scrapeConfigs =
        lib.optionals (config.sys.services.prometheusExporters.node.enable or false) [
          {
            job_name = "node";
            static_configs = [
              {
                targets = [
                  "localhost:${toString config.sys.services.prometheusExporters.node.port}"
                ];
              }
            ];
          }
        ]
        ++ lib.optionals (config.sys.services.prometheusExporters.nvidia.enable or false) [
          {
            job_name = "nvidia-gpu";
            static_configs = [
              {
                targets = [
                  "localhost:${toString config.sys.services.prometheusExporters.nvidia.port}"
                ];
              }
            ];
          }
        ]
        ++ cfg.extraScrapeConfigs;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
