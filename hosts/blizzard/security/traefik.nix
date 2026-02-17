{ config, VARS, ... }:
{
  services.traefik = {
    enable = true;

    dataDir = "/var/lib/traefik";

    dynamic = {
      dir = "/var/lib/traefik/dynamic";
    };

    static.settings = {
      accessLog.format = "json";
      log.level = "WARN";

      experimental.plugins.bouncer = {
        moduleName = "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin";
        version = "v1.4.5";
      };

      api = {
        dashboard = true;
        insecure = false;
      };

      entryPoints = {
        web = {
          address = ":80";
          forwardedHeaders = {
            trustedIPs = [
              "127.0.0.1/32"
              "10.0.0.0/8"
              "172.16.0.0/12"
              "192.168.0.0/16"
              "100.64.0.0/10"
            ];
          };
        };

        websecure = {
          address = ":443";
          forwardedHeaders = {
            trustedIPs = [
              "127.0.0.1/32"
              "10.0.0.0/8"
              "172.16.0.0/12"
              "192.168.0.0/16"
              "100.64.0.0/10"
            ];
          };
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
              crowdsecLapiKeyFile = "${config.sys.secrets.crowdsecTraefikBouncerTokenFile}";

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

          security-headers = {
            headers = {
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

          gitea-xfp-https = {
            headers.customRequestHeaders = {
              X-Forwarded-Proto = "https";
            };
          };

          firefox-headers = {
            headers = {
              customResponseHeaders = {
                X-Content-Type-Options = "nosniff";
                X-XSS-Protection = "1; mode=block";
                Referrer-Policy = "no-referrer";
                Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
              };
            };
          };

          brave-headers = {
            headers = {
              customResponseHeaders = {
                X-Content-Type-Options = "nosniff";
                X-XSS-Protection = "1; mode=block";
                Referrer-Policy = "no-referrer";
                Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
              };
            };
          };

          overseerr-headers = {
            headers = {
              customResponseHeaders = {
                X-Content-Type-Options = "nosniff";
                X-Frame-Options = "SAMEORIGIN";
                X-XSS-Protection = "1; mode=block";
                Referrer-Policy = "no-referrer-when-downgrade";
                Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
              };

              contentSecurityPolicy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://plex.tv https://*.plex.tv https://*.plex.direct wss://*.plex.direct; frame-src https://app.plex.tv;";
            };
          };

          tautulli-headers = {
            headers = {
              customResponseHeaders = {
                X-Content-Type-Options = "nosniff";
                X-Frame-Options = "SAMEORIGIN";
                X-XSS-Protection = "1; mode=block";
                Referrer-Policy = "no-referrer-when-downgrade";
                Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
              };

              contentSecurityPolicy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://plex.tv https://*.plex.tv https://*.plex.direct wss://*.plex.direct; frame-src https://app.plex.tv;";
            };
          };
        };

        routers = {
          traefik-dashboard = {
            rule = "Host(`${config.networking.hostName}.mole-delta.ts.net`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))";
            service = "api@internal";
            entryPoints = [ "websecure" ];
            tls.certResolver = "myresolver";
            middlewares = [ "security-headers" ];
          };

          overseerr = {
            rule = "Host(`requests.${VARS.domains.public}`)";
            service = "overseerr";
            entryPoints = [ "web" ];
            middlewares = [
              "overseerr-headers"
              "crowdsec"
            ];
          };

          firefox = {
            rule = "Host(`ff.${VARS.domains.public}`)";
            service = "firefox";
            entryPoints = [ "web" ];
            middlewares = [
              "firefox-headers"
              "crowdsec"
            ];
          };

          brave = {
            rule = "Host(`brave.${VARS.domains.public}`)";
            service = "brave";
            entryPoints = [ "web" ];
            middlewares = [
              "brave-headers"
              "crowdsec"
            ];
          };

          sabnzbd = {
            rule = "Host(`sab.${VARS.domains.public}`)";
            service = "sabnzbd";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          bazarr = {
            rule = "Host(`subs.${VARS.domains.public}`)";
            service = "bazarr";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          lingarr = {
            rule = "Host(`lingarr.${VARS.domains.public}`)";
            service = "lingarr";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          prowlarr = {
            rule = "Host(`indexer.${VARS.domains.public}`)";
            service = "prowlarr";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          radarr = {
            rule = "Host(`movies.${VARS.domains.public}`)";
            service = "radarr";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          readarr = {
            rule = "Host(`books.${VARS.domains.public}`)";
            service = "readarr";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          sonarr = {
            rule = "Host(`series.${VARS.domains.public}`)";
            service = "sonarr";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          searx = {
            rule = "Host(`search.${VARS.domains.public}`)";
            service = "searx";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          adguard = {
            rule = "Host(`adguard.${VARS.domains.public}`)";
            service = "adguard";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          actual = {
            rule = "Host(`actual.${VARS.domains.public}`)";
            service = "actual";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          ombi = {
            rule = "Host(`ombi.${VARS.domains.public}`)";
            service = "ombi";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "crowdsec"
            ];
          };

          tautulli = {
            rule = "Host(`tautulli.${VARS.domains.public}`)";
            service = "tautulli";
            entryPoints = [ "web" ];
            middlewares = [
              "tautulli-headers"
              "crowdsec"
            ];
          };

          gitea = {
            rule = "Host(`git.${VARS.domains.public}`)";
            service = "gitea";
            entryPoints = [ "web" ];
            middlewares = [
              "security-headers"
              "gitea-xfp-https"
              "crowdsec"
            ];
          };
        };

        services = {
          adguard.loadBalancer.servers = [ { url = "http://10.100.0.10:11010"; } ];
          searx.loadBalancer.servers = [ { url = "http://10.100.0.12:11012"; } ];
          prowlarr.loadBalancer.servers = [ { url = "http://10.100.0.20:11020"; } ];
          sonarr.loadBalancer.servers = [ { url = "http://10.100.0.21:11021"; } ];
          radarr.loadBalancer.servers = [ { url = "http://10.100.0.22:11022"; } ];
          bazarr.loadBalancer.servers = [ { url = "http://10.100.0.23:11023"; } ];
          readarr.loadBalancer.servers = [ { url = "http://10.100.0.24:11024"; } ];
          lingarr.loadBalancer.servers = [ { url = "http://localhost:11025"; } ];
          qbittorrent.loadBalancer.servers = [ { url = "http://10.100.0.30:11030"; } ];
          sabnzbd.loadBalancer.servers = [ { url = "http://10.100.0.31:11031"; } ];
          overseerr.loadBalancer.servers = [ { url = "http://10.100.0.40:11040"; } ];
          ombi.loadBalancer.servers = [ { url = "http://10.100.0.41:11041"; } ];
          tautulli.loadBalancer.servers = [ { url = "http://10.100.0.42:11042"; } ];
          gitea.loadBalancer.servers = [ { url = "http://10.100.0.50:11050"; } ];
          actual.loadBalancer.servers = [ { url = "http://10.100.0.51:11051"; } ];
          firefox.loadBalancer.servers = [ { url = "http://10.100.0.52:11052"; } ];
          # firefox occupies port 11053; no .53 IP shall be assigned
          brave.loadBalancer.servers = [ { url = "http://10.100.0.54:11054"; } ];
        };
      };
    };
  };

  systemd.services.traefik.serviceConfig = {
    BindReadOnlyPaths = [
      config.sys.secrets.crowdsecTraefikBouncerTokenFile
    ];
  };
}
