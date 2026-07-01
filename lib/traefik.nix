{ lib }:
let
  defaultPermissionsPolicy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
  defaultCsp = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self';";
  compatibilityCsp = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' ws: wss:; object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self';";
in
{
  inherit defaultPermissionsPolicy defaultCsp compatibilityCsp;

  # Build a Traefik middleware attrset with security response headers.
  # Pass null to any parameter to omit that header entirely.
  mkSecurityHeaders =
    {
      xFrameOptions ? "SAMEORIGIN",
      xssProtection ? "1; mode=block",
      referrerPolicy ? "no-referrer",
      permissionsPolicy ? defaultPermissionsPolicy,
      csp ? defaultCsp,
      extraResponseHeaders ? { },
      requestHeaders ? { },
    }:
    let
      optH = name: value: lib.optionalAttrs (value != null) { ${name} = value; };
    in
    {
      headers = {
        customResponseHeaders = {
          X-Content-Type-Options = "nosniff";
        }
        // optH "X-Frame-Options" xFrameOptions
        // optH "X-XSS-Protection" xssProtection
        // optH "Referrer-Policy" referrerPolicy
        // optH "Permissions-Policy" permissionsPolicy
        // extraResponseHeaders;
      }
      // lib.optionalAttrs (requestHeaders != { }) {
        customRequestHeaders = requestHeaders;
      }
      // lib.optionalAttrs (csp != null) {
        contentSecurityPolicy = csp;
      };
    };

  # Generate Traefik routers + services from a concise route table.
  #
  # Usage:
  #   mkRoutes { domain = VARS.domains.public; } {
  #     overseerr = { subdomain = "requests"; url = vmUrl "overseerr"; middlewares = [...]; };
  #     ...
  #   }
  #
  # Returns: { routers = { ... }; services = { ... }; }
  mkRoutes =
    {
      domain,
      defaultMiddlewares ? [
        "security-headers"
        "crowdsec"
      ],
    }:
    routes:
    let
      genRouter = name: route: {
        rule = "Host(`${route.subdomain}.${domain}`)";
        service = name;
        entryPoints = route.entryPoints or [ "web" ];
        middlewares = route.middlewares or defaultMiddlewares;
      };
      genService = name: route: {
        loadBalancer.servers = [ { inherit (route) url; } ];
      };
    in
    {
      routers = builtins.mapAttrs genRouter routes;
      services = builtins.mapAttrs genService routes;
    };

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

      middlewares = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = defaults.middlewares or null;
        description = "Traefik middleware chain to use instead of the default chain. When null, defaultMiddlewares is used.";
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
    let
      routeMiddlewares =
        if cfg.reverseProxy.middlewares != null then cfg.reverseProxy.middlewares else defaultMiddlewares;
    in
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
              middlewares = routeMiddlewares ++ cfg.reverseProxy.extraMiddlewares;
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
