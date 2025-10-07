{ lib, config, ... }:
let
  cfg = config.telometto.services.traefik;

  # Service type definition
  serviceType = lib.types.submodule {
    options = {
      backendUrl = lib.mkOption {
        type = lib.types.str;
        description = "Backend URL for the service (e.g., http://localhost:8080/)";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        description = "URL path prefix for routing (e.g., /app)";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to backend";
      };

      customHeaders = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = "Custom headers to add to requests";
        example = {
          X-Forwarded-Prefix = "/app";
        };
      };

      extraMiddlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional middleware names to apply";
      };
    };
  };

  # Helper to generate middleware name
  mkMiddlewareName = serviceName: suffix: "${serviceName}-${suffix}";

  # Generate middlewares for a service
  mkServiceMiddlewares =
    serviceName: serviceCfg:
    let
      baseMiddlewares = {
        headers = lib.mkIf (serviceCfg.customHeaders != null) {
          headers.customRequestHeaders = serviceCfg.customHeaders;
        };
      };
      stripMiddleware = lib.mkIf serviceCfg.stripPrefix {
        stripPrefix.prefixes = [ serviceCfg.pathPrefix ];
      };
    in
    lib.optionalAttrs (serviceCfg.customHeaders != null) {
      "${mkMiddlewareName serviceName "headers"}" = baseMiddlewares.headers;
    }
    // lib.optionalAttrs serviceCfg.stripPrefix {
      "${mkMiddlewareName serviceName "strip"}" = stripMiddleware;
    };

  # Generate router for a service
  mkServiceRouter =
    serviceName: serviceCfg:
    let
      appliedMiddlewares =
        [ ]
        ++ lib.optional (serviceCfg.customHeaders != null) (mkMiddlewareName serviceName "headers")
        ++ lib.optional serviceCfg.stripPrefix (mkMiddlewareName serviceName "strip")
        ++ serviceCfg.extraMiddlewares;
    in
    {
      rule = "Host(`${cfg.domain}`) && PathPrefix(`${serviceCfg.pathPrefix}`)";
      service = serviceName;
      middlewares = appliedMiddlewares;
      entrypoints = [ "websecure" ];
      tls = {
        certResolver = cfg.certResolver;
        domains = lib.optionals (cfg.domain != null) [
          { main = cfg.domain; }
        ];
      };
    };

  # Generate service definition
  mkServiceDef = serviceName: serviceCfg: {
    loadBalancer.servers = [ { url = serviceCfg.backendUrl; } ];
  };

  # Collect all generated configs
  generatedMiddlewares = lib.foldl' (
    acc: name: acc // (mkServiceMiddlewares name cfg.services.${name})
  ) { } (builtins.attrNames cfg.services);

  generatedRouters = lib.mapAttrs mkServiceRouter cfg.services;
  generatedServices = lib.mapAttrs mkServiceDef cfg.services;

  # Merge with user-provided configs
  finalStaticConfig = lib.recursiveUpdate cfg.staticConfigOptions cfg.staticConfigOverrides;

  finalDynamicConfig = {
    http = {
      middlewares = generatedMiddlewares // (cfg.dynamicConfigOptions.http.middlewares or { });
      routers = generatedRouters // (cfg.dynamicConfigOptions.http.routers or { });
      services = generatedServices // (cfg.dynamicConfigOptions.http.services or { });
    }
    // (builtins.removeAttrs (cfg.dynamicConfigOptions.http or { }) [
      "middlewares"
      "routers"
      "services"
    ]);
  }
  // (builtins.removeAttrs (cfg.dynamicConfigOptions or { }) [ "http" ]);
in
{
  options.telometto.services.traefik = {
    enable = lib.mkEnableOption "Traefik reverse proxy";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/traefik";
      description = "Directory where Traefik stores its data (e.g., acme.json for Let's Encrypt).";
    };

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default domain for all services";
      example = "example.com";
    };

    certResolver = lib.mkOption {
      type = lib.types.str;
      default = "myresolver";
      description = "Certificate resolver to use for TLS";
    };

    enableTailscaleCerts = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Tailscale certificate integration.
        This will configure Traefik to use Tailscale's TLS certificates.
      '';
    };

    services = lib.mkOption {
      type = lib.types.attrsOf serviceType;
      default = { };
      description = "Services to expose through Traefik with automatic middleware and router generation";
      example = {
        myapp = {
          backendUrl = "http://localhost:8080/";
          pathPrefix = "/myapp";
          stripPrefix = false;
        };
      };
    };

    certFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the TLS certificate file.
        If set, will be loaded securely via systemd LoadCredential.
      '';
    };

    keyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the TLS private key file.
        If set, will be loaded securely via systemd LoadCredential.
      '';
    };

    staticConfigOptions = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Static configuration options for Traefik.
        These are passed to services.traefik.staticConfigOptions.
        See https://doc.traefik.io/traefik/reference/static-configuration/overview/
      '';
    };

    staticConfigOverrides = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Static configuration overrides that take precedence over staticConfigOptions.
        Use this to override specific values from staticConfigOptions.
      '';
    };

    dynamicConfigOptions = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Dynamic configuration options for Traefik.
        These define routers, services, middlewares, and TLS configurations.
        Automatically generated configs from 'services' will be merged with these.
        See https://doc.traefik.io/traefik/reference/dynamic-configuration/overview/
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.traefik = {
      enable = true;
      dataDir = cfg.dataDir;
      staticConfigOptions = finalStaticConfig;
      dynamicConfigOptions = finalDynamicConfig;
    };

    # Allow Traefik to use Tailscale certificates
    services.tailscale.permitCertUid = lib.mkIf cfg.enableTailscaleCerts "traefik";

    # Securely load TLS certificates via systemd credentials
    systemd.services.traefik.serviceConfig = {
      LoadCredential = lib.optionals (cfg.certFile != null && cfg.keyFile != null) [
        "tls.crt:${cfg.certFile}"
        "tls.key:${cfg.keyFile}"
      ];
    };
  };
}
