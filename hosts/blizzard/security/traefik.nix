{
  config,
  lib,
  pkgs,
  VARS,
  consts,
  ...
}:
let
  reg = import ../../../vms/vm-registry.nix;
  traefikLib = import ../../../lib/traefik.nix { inherit lib; };
  vmUrl = name: "http://${reg.${name}.ip}:${toString reg.${name}.port}";
  vmInstances = config.sys.virtualisation.microvm.instances;
  enabledVmReverseProxies = lib.filterAttrs (
    _: instance: instance.enable && instance.reverseProxy.enable
  ) vmInstances;
  generatedVmRoutes = builtins.mapAttrs (
    _: instance:
    {
      inherit (instance.reverseProxy)
        subdomain
        url
        entryPoints
        ;
    }
    // lib.optionalAttrs (instance.reverseProxy.middlewares != null) {
      inherit (instance.reverseProxy) middlewares;
    }
  ) enabledVmReverseProxies;
  hostRoutes = {
    lingarr = {
      subdomain = "lingarr";
      url = "http://127.0.0.1:11025";
      middlewares = [
        "lingarr-headers"
        "crowdsec"
      ];
    };
  };
  generated = traefikLib.mkRoutes { domain = VARS.domains.public; } (generatedVmRoutes // hostRoutes);
  matrixSynapseEnabled = vmInstances."matrix-synapse".enable or false;

  trustedIPs = [
    "127.0.0.1/32"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10"
  ];

  plexCsp = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://plex.tv https://*.plex.tv https://*.plex.direct wss://*.plex.direct; frame-src https://app.plex.tv;";
in
{
  # Trust model: Traefik ↔ VM communication uses plain HTTP over an isolated
  # bridge network (10.100.0.0/24) that is not routable from external networks.
  services.traefik = {
    enable = true;

    static.settings = {
      accessLog.format = "json";
      log.level = "WARN";

      experimental.plugins.bouncer = {
        moduleName = "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin";
        version = "v1.4.5";
      };

      api.dashboard = true;

      entryPoints = {
        web = {
          address = ":80";
          forwardedHeaders = { inherit trustedIPs; };
        };
        websecure = {
          address = ":443";
          forwardedHeaders = { inherit trustedIPs; };
        };
      };

      certificatesResolvers.myresolver.tailscale = { };

      metrics.prometheus = {
        addEntryPointsLabels = true;
        addRoutersLabels = true;
        addServicesLabels = true;
      };
    };

    dynamic.files.core.settings = {
      http = {
        middlewares = {
          crowdsec = {
            plugin.bouncer = {
              enabled = true;
              crowdsecMode = "stream";
              crowdsecLapiScheme = "http";
              crowdsecLapiHost = "127.0.0.1:8085";
              crowdsecLapiKeyFile = "/run/traefik/crowdsec-bouncer-key";
              forwardedHeadersTrustedIPs = [
                "127.0.0.1/32"
                "173.245.48.0/20"
                "103.21.244.0/22"
                "103.22.200.0/22"
                "103.31.4.0/22"
                "141.101.64.0/18"
                "108.162.192.0/18"
                "190.93.240.0/20"
                "188.114.96.0/20"
                "197.234.240.0/22"
                "198.41.128.0/17"
                "162.158.0.0/15"
                "104.16.0.0/13"
                "104.24.0.0/14"
                "172.64.0.0/13"
                "131.0.72.0/22"
              ];
            };
          };

          security-headers = traefikLib.mkSecurityHeaders { };

          lingarr-headers = traefikLib.mkSecurityHeaders {
            csp = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' ws: wss:;";
          };

          gitea-xfp-https.headers.customRequestHeaders.X-Forwarded-Proto = "https";

          # Django CSRF requires the Referer header, which "no-referrer" strips.
          # See: https://github.com/paperless-ngx/paperless-ngx/discussions/5684
          csrf-safe-headers = traefikLib.mkSecurityHeaders {
            referrerPolicy = "same-origin";
            requestHeaders.X-Forwarded-Proto = "https";
          };

          firefly-headers = traefikLib.mkSecurityHeaders {
            referrerPolicy = "strict-origin-when-cross-origin";
            requestHeaders = {
              X-Forwarded-Port = "443";
              X-Forwarded-Proto = "https";
            };
          };

          firefox-headers = traefikLib.mkSecurityHeaders {
            xFrameOptions = null;
            csp = null;
          };

          # Matrix needs relaxed headers: no CSP (Element/clients make
          # cross-origin requests) and DENY framing to prevent click-jacking.
          # CORS headers are set here so browsers (and tools like the Matrix
          # connectivity tester) can reach all API/well-known endpoints.
          matrix-headers = traefikLib.mkSecurityHeaders {
            xFrameOptions = "DENY";
            xssProtection = "0";
            referrerPolicy = "strict-origin-when-cross-origin";
            permissionsPolicy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()";
            csp = null;
            extraResponseHeaders = {
              Access-Control-Allow-Origin = "*";
              Access-Control-Allow-Methods = "GET, HEAD, POST, PUT, DELETE, OPTIONS";
              Access-Control-Allow-Headers = "X-Requested-With, Content-Type, Authorization, Date";
              Access-Control-Expose-Headers = "Content-Length, Content-Type, Content-Disposition";
            };
          };

          # Plex-adjacent services (Overseerr, Tautulli) — relaxed referrer + Plex CSP
          plex-headers = traefikLib.mkSecurityHeaders {
            referrerPolicy = "no-referrer-when-downgrade";
            csp = plexCsp;
          };
        };

        routers =
          generated.routers
          // {
            traefik-dashboard = {
              rule = "Host(`${config.networking.hostName}.${consts.tailscale.suffix}`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))";
              service = "api@internal";
              entryPoints = [ "websecure" ];
              tls.certResolver = "myresolver";
              middlewares = [ "security-headers" ];
            };
          }
          // lib.optionalAttrs matrixSynapseEnabled {
            matrix-synapse = {
              rule = "Host(`matrix.${VARS.domains.public}`)";
              service = "matrix-synapse";
              entryPoints = [ "web" ];
              middlewares = [ "matrix-headers" ];
            };

            matrix-well-known = {
              rule = "Host(`${VARS.domains.public}`) && PathPrefix(`/.well-known/matrix/`)";
              service = "matrix-synapse";
              entryPoints = [ "web" ];
              middlewares = [ "matrix-headers" ];
            };
          };

        services =
          generated.services
          // lib.optionalAttrs matrixSynapseEnabled {
            matrix-synapse.loadBalancer.servers = [ { url = vmUrl "matrix-synapse"; } ];
          };
      };
    };
  };

  systemd.services.traefik.serviceConfig = {
    # Copy the bouncer token into Traefik's RuntimeDirectory so the
    # DynamicUser can read it without making the SOPS source world-readable.
    # The directory is 0750 (only root + dynamic user), so 0444 on the copy
    # is safe — no other user can even enter the directory.
    RuntimeDirectory = "traefik";
    RuntimeDirectoryMode = "0750";
    ExecStartPre = [
      "+${pkgs.writeShellScript "copy-bouncer-key" ''
        set -euo pipefail
        install -m 0444 ${config.sys.secrets.crowdsecTraefikBouncerTokenFile} /run/traefik/crowdsec-bouncer-key
      ''}"
    ];
  };
}
