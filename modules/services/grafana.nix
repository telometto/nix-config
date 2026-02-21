{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.grafana;
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.grafana = {
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

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "grafana"; };
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

        security.secret_key = "$__file{${
          config.sys.secrets.grafanaSecretKeyFile or "/run/secrets/grafana-secret-key"
        }}";

        analytics.reporting_enabled = !cfg.disableTelemetry;
      } cfg.extraSettings;

      provision = lib.mkIf cfg.provision.enable {
        enable = true;

        datasources.settings = {
          apiVersion = 1;
          datasources =
            lib.optionals (config.sys.services.prometheus.enable or false) [
              {
                name = "Prometheus";
                type = "prometheus";
                url = "http://${config.sys.services.prometheus.listenAddress}:${toString config.sys.services.prometheus.port}";
                isDefault = true;
                editable = false;
              }
            ]
            ++ cfg.provision.datasources;
        };

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

    environment.etc = lib.mapAttrs' (name: path: {
      name = "grafana-dashboards/${name}.json";
      value.source = path;
    }) cfg.provision.dashboards;

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    services.traefik.dynamic.files.grafana = traefikLib.mkTraefikDynamicConfig {
      name = "grafana";
      inherit cfg config;
      inherit (cfg) port;
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion {
        name = "grafana";
        inherit cfg;
      })
    ];
  };
}
