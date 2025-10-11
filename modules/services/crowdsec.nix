{
  lib,
  config,
  pkgs,
  ...
}:
# Namespace & layering notes:
# - This module owns options under `telometto.services.crowdsec.*`.
# - Other modules should not redeclare these options; they may set sub-options
#   we expose (e.g., hub collections, local configs) to avoid namespace collisions.
# - Use mkDefault in core, mkOverride in roles/features, mkForce in host overrides
#   for predictable precedence.
let
  cfg = config.telometto.services.crowdsec;
in
{
  options.telometto.services.crowdsec = {
    enable = lib.mkEnableOption "CrowdSec security engine";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.crowdsec;
      defaultText = lib.literalExpression "pkgs.crowdsec";
      description = "The CrowdSec package to use.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to automatically open firewall ports for CrowdSec.";
    };

    autoUpdateService = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to automatically update the Hub.";
    };

    # Hub configuration - most common use case
    hub = {
      collections = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "crowdsecurity/linux"
          "crowdsecurity/unifi"
          "crowdsecurity/traefik"
          "crowdsecurity/windows-firewall"
        ];
        description = "List of hub collections to install.";
        example = [
          "crowdsecurity/linux"
          "crowdsecurity/nginx"
        ];
      };

      scenarios = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "crowdsecurity/ssh-bf" # ssh brute force
          "crowdsecurity/ssh-slow-bf" # ssh slow brute force
          "crowdsecurity/amavis-blocked" # ban IPs blocked by amavis
          "crowdsecurity/jellyfin-bf" # detect jellyfin brute force
          "crowdsecurity/overseerr-bf"
        ];
        description = "List of hub scenarios to install.";
        example = [
          "crowdsecurity/ssh-bf"
          "crowdsecurity/http-probing"
        ];
      };

      parsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of hub parsers to install.";
        example = [
          "crowdsecurity/sshd-logs"
          "crowdsecurity/nginx-logs"
        ];
      };

      postOverflows = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "crowdsecurity/auditd-nix-wrappers-whitelist-process"
        ];
        description = "List of hub postoverflows to install.";
        example = [ "crowdsecurity/rdns" ];
      };

      appSecConfigs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of hub AppSec configs to install.";
        example = [ "crowdsecurity/appsec-default" ];
      };

      appSecRules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of hub AppSec rules to install.";
        example = [ "crowdsecurity/vpatch-cve-2021-44228" ];
      };
    };

    # Local configuration - for custom parsers, scenarios, etc.
    localConfig = {
      acquisitions = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Data source acquisitions for CrowdSec to parse.";
        example = lib.literalExpression ''
          [
            {
              source = "journalctl";
              journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
              labels = {
                type = "syslog";
              };
            }
          ]
        '';
      };

      scenarios = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Custom scenario specifications.";
      };

      parsers = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Custom parser specifications.";
      };

      postOverflows = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Custom postoverflow specifications.";
      };

      contexts = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Additional alert contexts to specify.";
      };

      notifications = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Notification plugins to enable.";
        example = lib.literalExpression ''
          [
            {
              type = "http";
              name = "webhook_notification";
              log_level = "info";
              format = "{{.|toJson}}";
              url = "https://example.com/webhook";
              method = "POST";
            }
          ]
        '';
      };

      profiles = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [
          {
            name = "default_ip_remediation";
            filters = [ "Alert.Remediation == true && Alert.GetScope() == 'Ip'" ];
            decisions = [
              {
                type = "ban";
                duration = "4h";
              }
            ];
            on_success = "break";
          }
        ];
        description = "Decision profiles for CrowdSec.";
      };

      patterns = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "List of pattern packages containing custom grok patterns.";
        example = lib.literalExpression ''
          [ pkgs.my-custom-patterns ]
        '';
      };
    };

    # Settings extension point
    settings = {
      general = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional general settings to merge with defaults.";
      };

      simulation = lib.mkOption {
        type = lib.types.attrs;
        default = {
          simulation = false;
        };
        description = "Simulation mode configuration.";
      };

      lapi = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable the Local API (LAPI) server.";
        };

        credentialsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to LAPI credentials file.";
          example = "/run/secrets/crowdsec-lapi";
        };

        listenUri = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1:8085";
          description = "LAPI listen URI.";
        };
      };

      capi = {
        credentialsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to CAPI credentials file for sharing signals with CrowdSec central API.";
          example = "/run/secrets/crowdsec-capi";
        };
      };

      console = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to enable CrowdSec console enrollment.";
        };

        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to file containing console enrollment token.";
          example = "/run/secrets/crowdsec-console-token";
        };
      };

      prometheus = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable Prometheus metrics.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 6060;
          description = "Port for Prometheus metrics endpoint.";
        };
      };
    };

    # Additional extension points
    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional settings merged into services.crowdsec (owner extension point).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.crowdsec = lib.mkMerge [
      {
        enable = true;
        inherit (cfg) package openFirewall autoUpdateService;

        # Hub configuration
        hub = {
          inherit (cfg.hub)
            collections
            scenarios
            parsers
            postOverflows
            appSecConfigs
            appSecRules
            ;
        };

        # Local configuration
        localConfig = lib.mkMerge [
          {
            inherit (cfg.localConfig)
              acquisitions
              scenarios
              parsers
              postOverflows
              contexts
              notifications
              profiles
              patterns
              ;
          }
        ];

        # Settings
        settings = lib.mkMerge [
          {
            general = lib.mkMerge [
              {
                api.server = {
                  enable = cfg.settings.lapi.enable;
                  listen_uri = cfg.settings.lapi.listenUri;
                };
                prometheus = {
                  enabled = cfg.settings.prometheus.enable;
                  listen_port = cfg.settings.prometheus.port;
                };
              }
              cfg.settings.general
            ];

            simulation = cfg.settings.simulation;

            lapi.credentialsFile =
              if cfg.settings.lapi.credentialsFile != null then
                cfg.settings.lapi.credentialsFile
              else if cfg.settings.lapi.enable then
                # Provide a default path if LAPI is enabled but no file specified
                "/var/lib/crowdsec/data/local_api_credentials.yaml"
              else
                null;

            capi.credentialsFile =
              if cfg.settings.capi.credentialsFile != null then cfg.settings.capi.credentialsFile else null;

            console.tokenFile =
              if cfg.settings.console.enable && cfg.settings.console.tokenFile != null then
                cfg.settings.console.tokenFile
              else
                null;
          }
          cfg.extraSettings
        ];
      }
      cfg.extraSettings
    ];
  };
}
