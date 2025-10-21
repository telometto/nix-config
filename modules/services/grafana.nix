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

    # Contribute to Traefik configuration if reverse proxy is enabled and Traefik is available
    telometto.services.traefik =
      lib.mkIf (cfg.reverseProxy.enable && config.telometto.services.traefik.enable or false)
        {
          # Services: path-based for Tailscale and optionally domain-based for Cloudflare
          services = {
            # Main path-based service (for Tailscale: blizzard.ts.net/grafana)
            grafana = {
              backendUrl = "http://localhost:${toString cfg.port}/";
              inherit (cfg.reverseProxy) pathPrefix stripPrefix extraMiddlewares;
              customHeaders = {
                X-Forwarded-Proto = "https";
                X-Forwarded-Host =
                  config.telometto.services.traefik.domain or "${config.networking.hostName}.local";
              };
            };
          }
          // lib.optionalAttrs (cfg.reverseProxy.domain != null) {
            # Additional domain-based service (for Cloudflare: grafana.example.com)
            "grafana-domain" = {
              backendUrl = "http://localhost:${toString cfg.port}/";
              pathPrefix = "/";
              stripPrefix = false;
              extraMiddlewares = cfg.reverseProxy.extraMiddlewares;
              customHeaders = {
                X-Forwarded-Proto = "https";
                X-Forwarded-Host = cfg.reverseProxy.domain;
              };
            };
          };

          # Override the router rule for the domain-based service
          dynamicConfigOptions = lib.mkIf (cfg.reverseProxy.domain != null) {
            http.routers."grafana-domain" = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "grafana-domain";
              entrypoints = [ "websecure" ];
              tls.certResolver = config.telometto.services.traefik.certResolver or "myresolver";
            };
          };
        };
  };
}
