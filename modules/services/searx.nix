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

    # Contribute to Traefik configuration if reverse proxy is enabled and Traefik is available
    telometto.services.traefik.services = lib.mkIf (
      cfg.reverseProxy.enable && config.telometto.services.traefik.enable or false
    ) {
      searx = {
        backendUrl = "http://localhost:${toString cfg.port}/";

        inherit (cfg.reverseProxy) pathPrefix stripPrefix extraMiddlewares;

        customHeaders = {
          X-Forwarded-Proto = "https";
          X-Forwarded-Host = config.telometto.services.traefik.domain or "${config.networking.hostName}.local";
        };
      };
    };
  };
}
