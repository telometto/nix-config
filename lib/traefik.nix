{ lib }:
{
  mkReverseProxyOptions =
    {
      name,
      defaults ? { },
    }:
    {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = defaults.enable or true;
        description = "Enable Traefik reverse proxy configuration.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = defaults.domain or null;
        description = "Domain for hostname-based routing.";
        example = "${name}.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = defaults.pathPrefix or "/${name}";
        description = "URL path prefix for this service.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = defaults.stripPrefix or false;
        description = "Whether to strip the path prefix before forwarding.";
      };

      extraMiddlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = defaults.extraMiddlewares or [ ];
        description = "Additional Traefik middlewares to apply.";
      };

      cfTunnel = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = defaults.cfTunnelEnable or false;
          description = "Enable Cloudflare Tunnel ingress for this service.";
        };
      };
    };

  mkTraefikDynamicConfig =
    {
      name,
      cfg,
      config,
      port,
      defaultMiddlewares ? [ "security-headers" ],
      extraDynamicConfig ? { },
    }:
    lib.mkIf
      (
        cfg.reverseProxy.enable
        && cfg.reverseProxy.domain != null
        && config.services.traefik.enable or false
      )
      {
        settings = {
          http = lib.recursiveUpdate {
            routers.${name} = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = name;
              entryPoints = [ "web" ];
              middlewares = defaultMiddlewares ++ cfg.reverseProxy.extraMiddlewares;
            };

            services.${name}.loadBalancer = {
              servers = [ { url = "http://localhost:${toString port}"; } ];
              passHostHeader = true;
            };
          } extraDynamicConfig;
        };
      };

  mkCfTunnelAssertion =
    { name, cfg }:
    {
      assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
      message = "sys.services.${name}.reverseProxy.domain must be set when cfTunnel.enable is true";
    };
}
