{ config, VARS, ... }:
{
  services.traefik = {
    enable = true;

    dataDir = "/var/lib/traefik";

    staticConfigOptions = {
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

    dynamicConfigOptions = {
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
              "security-headers"
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
          overseerr.loadBalancer.servers = [ { url = "http://10.100.0.13:11001"; } ];
          prowlarr.loadBalancer.servers = [ { url = "http://10.100.0.19:11025"; } ];
          sonarr.loadBalancer.servers = [ { url = "http://10.100.0.17:11023"; } ];
          radarr.loadBalancer.servers = [ { url = "http://10.100.0.18:11024"; } ];
          readarr.loadBalancer.servers = [ { url = "http://10.100.0.21:11027"; } ];
          bazarr.loadBalancer.servers = [ { url = "http://10.100.0.20:11026"; } ];
          lingarr.loadBalancer.servers = [ { url = "http://localhost:10031"; } ];
          sabnzbd.loadBalancer.servers = [ { url = "http://10.100.0.24:11050"; } ];
          firefox.loadBalancer.servers = [ { url = "http://10.100.0.25:11060"; } ];
          searx.loadBalancer.servers = [ { url = "http://10.100.0.12:11002"; } ];
          adguard.loadBalancer.servers = [ { url = "http://10.100.0.10:11016"; } ];
          actual.loadBalancer.servers = [ { url = "http://10.100.0.11:11005"; } ];
          ombi.loadBalancer.servers = [ { url = "http://10.100.0.14:11003"; } ];
          tautulli.loadBalancer.servers = [ { url = "http://10.100.0.15:11004"; } ];
          gitea.loadBalancer.servers = [ { url = "http://10.100.0.16:11015"; } ];
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
