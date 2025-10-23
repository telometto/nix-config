{ lib, config, ... }:
let
  cfg = config.telometto.services.searx or { };
in
{
  options.telometto.services.searx = {
    enable = lib.mkEnableOption "Searx Meta Search";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7777;
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Owner/extension point merged into services.searx.settings.";
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Searx.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "searx.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "searx.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/searx";
        description = "URL path prefix for Searx.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Searx.";
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
    services.searx = {
      enable = true;
      redisCreateLocally = true;
      settings = lib.mkMerge [
        {
          server = {
            # Use centralized secrets bridge; avoids direct SOPS references here
            secret_key = config.telometto.secrets.searxSecretKeyFile;
            inherit (cfg) port;
            bind_address = cfg.bind;
          };
          search.formats = [
            "html"
            "json"
            "rss"
          ];
          # Redis has been renamed to Valkey in NixOS settings, but the service path remains redis
          valkey.url = lib.mkIf config.services.searx.redisCreateLocally "unix://${config.services.redis.servers.searx.unixSocket}";
        }
        cfg.settings
      ];
    };

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
            routers.searx = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "searx";
              entryPoints = [ "web" ];
            };

            services.searx.loadBalancer = {
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
        message = "telometto.services.searx.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
