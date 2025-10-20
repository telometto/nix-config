{ lib, config, ... }:
let
  cfg = config.telometto.services.prometheus;
in
{
  options.telometto.services.prometheus = {
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
      enable = true;
      inherit (cfg) port listenAddress retentionTime;

      webExternalUrl = lib.mkIf (cfg.webExternalUrl != null) cfg.webExternalUrl;

      globalConfig = {
        inherit (cfg) scrapeInterval;
      };

      # Scrape configurations: auto-configure node exporter if enabled, plus any extras
      scrapeConfigs =
        lib.optionals (config.telometto.services.prometheusExporters.node.enable or false) [
          {
            job_name = "node";
            static_configs = [
              {
                targets = [
                  "localhost:${toString config.telometto.services.prometheusExporters.node.port}"
                ];
              }
            ];
          }
        ]
        ++ cfg.extraScrapeConfigs;
    };

    # Open firewall if requested
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    # Contribute to Traefik configuration if reverse proxy is enabled and Traefik is available
    telometto.services.traefik.services =
      lib.mkIf (cfg.reverseProxy.enable && config.telometto.services.traefik.enable or false)
        {
          prometheus = {
            backendUrl = "http://localhost:${toString cfg.port}/";

            inherit (cfg.reverseProxy) pathPrefix stripPrefix extraMiddlewares;

            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host =
                config.telometto.services.traefik.domain or "${config.networking.hostName}.local";
            };
          };
        };
  };
}
