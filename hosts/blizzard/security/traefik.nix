{
  config,
  lib,
  pkgs,
  VARS,
  consts,
  ...
}:
let
  traefikLib = import ../../../lib/traefik.nix { inherit lib; };
  vmInstances = config.sys.virtualisation.microvm.instances;
  hostRoutes = {
    lingarr = {
      subdomain = "lingarr";
      url = "http://127.0.0.1:11025";
      middlewares = [
        "lingarr-headers"
        "crowdsec"
      ];
    };
    nominatim = {
      subdomain = "nominatim";
      url = "http://127.0.0.1:11080";
    };
  };
  generated = traefikLib.mkRoutes { domain = VARS.domains.public; } hostRoutes;
  matrixSynapsePublished =
    (vmInstances."matrix-synapse".enable or false)
    && (vmInstances."matrix-synapse".publication.enable or false);

  trustedIPs = [
    "127.0.0.1/32"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10"
  ];

  immichUploadTimeouts = {
    transport.respondingTimeouts = {
      readTimeout = "600s";
      idleTimeout = "600s";
    };
  };

  # Plex OAuth and web clients still require inline/eval allowances; keep this
  # policy scoped to Plex-family routes instead of using it as a default.
  plexCsp = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://plex.tv https://*.plex.tv https://*.plex.direct wss://*.plex.direct; frame-src https://app.plex.tv;";
in
{
  services.traefik.publicationPolicyMiddlewares = {
    browser-in-browser = [ "firefox-headers" ];
    csrf-compatible = [ "csrf-safe-headers" ];
    dynamic-app-shell = [ "trigger-headers" ];
    firefly-proxy = [ "firefly-headers" ];
    immich-web = [ "immich-headers" ];
    legacy-app-shell = [ "app-compat-headers" ];
    matrix-compatible = [ "matrix-headers" ];
    oidc-provider = [ "pocket-id-headers" ];
    plex-compatible = [ "plex-headers" ];
    sabnzbd-ui = [ "sabnzbd-headers" ];
    strict-forwarded-https = [
      "security-headers"
      "gitea-xfp-https"
    ];
  };

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
        # Cloudflare Tunnel terminates public HTTPS and forwards to this
        # entrypoint, so Immich's large uploads need the longer timeout here.
        web = immichUploadTimeouts // {
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

          # Legacy app shells such as Grafana and the Arr family still need
          # inline/eval script allowances and WebSocket connections. Keep this
          # scoped to those routes instead of relaxing the shared default.
          app-compat-headers = traefikLib.mkSecurityHeaders {
            csp = traefikLib.compatibilityCsp;
          };

          # Lingarr currently needs inline/eval script allowances and
          # WebSocket connections; keep this exception route-scoped.
          lingarr-headers = traefikLib.mkSecurityHeaders {
            csp = traefikLib.compatibilityCsp;
          };

          gitea-xfp-https.headers.customRequestHeaders.X-Forwarded-Proto = "https";

          immich-headers = traefikLib.mkSecurityHeaders {
            # Immich 2.7+ serves its packaged Helmet policy when
            # IMMICH_HELMET_FILE=true in vms/immich.nix. Avoid injecting a
            # second, incompatible proxy policy; re-check the response header
            # and web/mobile flows after every Immich upgrade.
            csp = null;
            requestHeaders.X-Forwarded-Proto = "https";
          };

          sabnzbd-headers = traefikLib.mkSecurityHeaders {
            # SABnzbd's web UI uses inline/dynamic frontend assets. Keep the
            # no-CSP exception scoped to this route.
            csp = null;
            requestHeaders.X-Forwarded-Proto = "https";
          };

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
            # Browser-in-browser UIs use nested frames and dynamic client code.
            xFrameOptions = null;
            csp = null;
          };

          trigger-headers = traefikLib.mkSecurityHeaders {
            # Trigger.dev's app shell currently needs a service-specific CSP
            # review; keep no-CSP scoped to the Trigger route only.
            csp = null;
          };

          pocket-id-headers = traefikLib.mkSecurityHeaders {
            # Pocket ID is the public WebAuthn/OIDC authority. Do not inject a
            # CSP that can interfere with its UI, and never allow framing.
            xFrameOptions = "DENY";
            csp = null;
            requestHeaders.X-Forwarded-Proto = "https";
          };

          # Matrix needs relaxed headers for federated clients and well-known
          # discovery. CORS is kept on the explicit Matrix discovery responses
          # in the guest Nginx route, not injected across the hostname.
          matrix-headers = traefikLib.mkSecurityHeaders {
            xFrameOptions = "DENY";
            xssProtection = "0";
            referrerPolicy = "strict-origin-when-cross-origin";
            permissionsPolicy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()";
            csp = null;
          };

          # Plex-adjacent services need Plex OAuth/referrer compatibility; keep
          # this separate from the default security headers.
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
          // lib.optionalAttrs matrixSynapsePublished {
            matrix-well-known = {
              rule = "Host(`${VARS.domains.public}`) && PathPrefix(`/.well-known/matrix/`)";
              service = "matrix-synapse";
              entryPoints = [ "web" ];
              middlewares = [
                "matrix-headers"
                "crowdsec"
              ];
            };
          };

        inherit (generated) services;
      };
    };
  };

  systemd.services.traefik.serviceConfig = {
    # Copy the bouncer token into Traefik's RuntimeDirectory so the
    # DynamicUser can read it without making the SOPS source world-readable.
    # The directory is 0750 (only root + dynamic user), so 0444 on the copy
    # is safe - no other user can even enter the directory.
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
