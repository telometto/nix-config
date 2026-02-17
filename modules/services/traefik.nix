{ lib, config, ... }:
let
  cfg = config.sys.services.traefik;

  trustedIPs = [
    "127.0.0.1/32"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10"
  ];
in
{
  options.sys.services.traefik = {
    enable = lib.mkEnableOption "Traefik reverse proxy";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/traefik";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [
        "DEBUG"
        "INFO"
        "WARN"
        "ERROR"
      ];
      default = "WARN";
    };

    accessLog = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    metrics = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    dashboard = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "traefik.example.com";
      };
    };

    entryPoints = lib.mkOption {
      type = lib.types.attrs;
      default = {
        web = {
          address = ":80";
          forwardedHeaders.trustedIPs = trustedIPs;
        };
        websecure = {
          address = ":443";
          forwardedHeaders.trustedIPs = trustedIPs;
        };
      };
    };

    certResolvers = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = lib.literalExpression "{ myresolver.tailscale = {}; }";
    };

    securityHeaders = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    staticConfigOverrides = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Deep-merged last into static configuration (escape hatch).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.traefik = {
      enable = true;
      dataDir = cfg.dataDir;

      dynamic.dir = "${cfg.dataDir}/dynamic";

      static.settings = lib.recursiveUpdate (
        {
          log.level = cfg.logLevel;
          entryPoints = cfg.entryPoints;
        }
        // lib.optionalAttrs (cfg.certResolvers != { }) {
          certificatesResolvers = cfg.certResolvers;
        }
        // lib.optionalAttrs cfg.dashboard.enable {
          api = {
            dashboard = true;
            insecure = false;
          };
        }
        // lib.optionalAttrs cfg.accessLog {
          accessLog.format = "json";
        }
        // lib.optionalAttrs cfg.metrics {
          metrics.prometheus = {
            addEntryPointsLabels = true;
            addRoutersLabels = true;
            addServicesLabels = true;
          };
        }
      ) cfg.staticConfigOverrides;

      dynamic.files.core.settings.http = {
        middlewares = lib.optionalAttrs cfg.securityHeaders {
          security-headers.headers = {
            customResponseHeaders = {
              X-Content-Type-Options = "nosniff";
              X-Frame-Options = "SAMEORIGIN";
              X-XSS-Protection = "1; mode=block";
              Referrer-Policy = "no-referrer";
              Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
            };

            contentSecurityPolicy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self';";
          };
        };

        routers = lib.optionalAttrs cfg.dashboard.enable {
          traefik-dashboard =
            {
              rule = "Host(`${cfg.dashboard.domain}`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))";
              service = "api@internal";
              entryPoints = [ "websecure" ];
              middlewares = [ "security-headers" ];
            }
            // lib.optionalAttrs (cfg.certResolvers != { }) {
              tls.certResolver = builtins.head (builtins.attrNames cfg.certResolvers);
            };
        };
      };
    };

    services.tailscale.permitCertUid = "traefik";

    assertions = [
      {
        assertion = !cfg.dashboard.enable || cfg.dashboard.domain != null;
        message = "sys.services.traefik.dashboard.domain must be set when dashboard is enabled";
      }
    ];
  };
}
