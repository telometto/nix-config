{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.grafana;
in
{
  options.telometto.services.grafana = {
    enable = lib.mkEnableOption "Grafana visualization and dashboarding";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port on which Grafana listens";
    };

    addr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which Grafana listens";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "The public facing domain name used to access Grafana from a browser";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for Grafana port";
    };

    provision = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable declarative provisioning of datasources and dashboards";
      };

      datasources = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Declaratively provisioned datasources";
        example = lib.literalExpression ''
          [
            {
              name = "Prometheus";
              type = "prometheus";
              url = "http://localhost:9090";
              isDefault = true;
            }
          ]
        '';
      };

      dashboards = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        description = "Declaratively provisioned dashboards as name-path pairs";
        example = lib.literalExpression ''
          {
            "node-exporter" = ./dashboards/node-exporter.json;
          }
        '';
      };
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional Grafana plugins to install";
      example = lib.literalExpression "[ pkgs.grafanaPlugins.grafana-clock-panel ]";
    };

    disableTelemetry = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable Grafana phone-home telemetry";
    };

    subPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        URL subpath for Grafana when behind a reverse proxy.
        Example: "/grafana" will make Grafana accessible at https://domain.com/grafana/
      '';
      example = "/grafana";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional settings to merge into services.grafana.settings";
      example = lib.literalExpression ''
        {
          security = {
            admin_password = "$__file{/run/secrets/grafana-admin-password}";
          };
        }
      '';
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Grafana.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "grafana.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "grafana.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/grafana";
        description = "URL path prefix for Grafana.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Grafana.";
      };

      extraMiddlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional Traefik middlewares to apply.";
      };

      cfTunnel = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable Cloudflare Tunnel ingress for this service.
            When enabled, automatically adds this service to the Cloudflare Tunnel ingress configuration.
            Requires reverseProxy.enable = true and reverseProxy.domain to be set.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.grafana = {
      enable = true;
      declarativePlugins = cfg.plugins;

      settings = lib.recursiveUpdate {
        server = {
          http_addr = cfg.addr;
          http_port = cfg.port;
          inherit (cfg) domain;
          enforce_domain = true;
          enable_gzip = true;
        }
        // lib.optionalAttrs (cfg.subPath != null) {
          root_url = "https://${cfg.domain}${cfg.subPath}/";
          serve_from_sub_path = true;
        };

        # Prevent Grafana from phoning home
        analytics.reporting_enabled = !cfg.disableTelemetry;
      } cfg.extraSettings;

      provision = lib.mkIf cfg.provision.enable {
        enable = true;

        # Provision datasources
        datasources.settings = {
          apiVersion = 1;
          datasources =
            # Auto-provision Prometheus if it's enabled
            lib.optionals (config.telometto.services.prometheus.enable or false) [
              {
                name = "Prometheus";
                type = "prometheus";
                url = "http://${config.telometto.services.prometheus.listenAddress}:${toString config.telometto.services.prometheus.port}";
                isDefault = true;
                editable = false;
              }
            ]
            ++ cfg.provision.datasources;
        };

        # Provision dashboards if any are specified
        dashboards.settings = lib.mkIf (cfg.provision.dashboards != { }) {
          apiVersion = 1;
          providers = [
            {
              name = "default";
              options.path = "/etc/grafana-dashboards";
              disableDeletion = true;
              editable = false;
            }
          ];
        };
      };
    };

    # Install dashboard files if provisioned
    environment.etc = lib.mapAttrs' (name: path: {
      name = "grafana-dashboards/${name}.json";
      value.source = path;
    }) cfg.provision.dashboards;

    # Open firewall if requested
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    # Configure Traefik reverse proxy if enabled
    services.traefik.dynamicConfigOptions =
      lib.mkIf
        (
          cfg.reverseProxy.enable
          && cfg.reverseProxy.domain != null
          && config.services.traefik.enable or false
        )
        {
          http = {
            routers.grafana = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "grafana";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            services.grafana.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
            };
          };
        };

    # Configure Cloudflare Tunnel ingress if enabled
    telometto.services.cloudflared.ingress =
      lib.mkIf
        (
          cfg.reverseProxy.cfTunnel.enable
          && cfg.reverseProxy.enable
          && cfg.reverseProxy.domain != null
          && config.telometto.services.cloudflared.enable or false
        )
        {
          "${cfg.reverseProxy.domain}" = "http://localhost:80";
        };

    # Validate configuration
    assertions = [
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "telometto.services.grafana.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
