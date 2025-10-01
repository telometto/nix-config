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
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = cfg.port;
      listenAddress = cfg.listenAddress;
      retentionTime = cfg.retentionTime;

      globalConfig = {
        scrape_interval = cfg.scrapeInterval;
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
  };
}
