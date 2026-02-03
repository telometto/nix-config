{ lib, config, ... }:
{
  # Traefik static configuration specific to blizzard host
  services.traefik = {
    enable = true;
    dataDir = "/var/lib/traefik";

    staticConfigOptions = {
      accessLog = {
        format = "json";
      };

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

    dynamicConfigOptions.http = {
      middlewares.crowdsec = {
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

      routers.traefik-dashboard = {
        rule = "Host(`${config.networking.hostName}.mole-delta.ts.net`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))";
        service = "api@internal";
        entryPoints = [ "websecure" ];
        tls.certResolver = "myresolver";
        middlewares = [ "security-headers" ];
      };
    };
  };

  systemd.services.traefik.serviceConfig = {
    BindReadOnlyPaths = [
      config.sys.secrets.crowdsecTraefikBouncerTokenFile
    ];
  };

  services.tailscale.permitCertUid = lib.mkIf config.services.traefik.enable "traefik";
}
