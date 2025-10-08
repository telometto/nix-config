{
  config,
  lib,
  VARS,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ];

  networking = {
    hostName = lib.mkForce "snowfall";
    hostId = lib.mkForce "131b6b39";
  };

  telometto = {
    role.desktop.enable = true;

    desktop.flavor = "kde";

    programs.nix-ld.enable = false;

    # Pull specific packages from different nixpkgs inputs
    # overlays.fromInputs = {
    #   nixpkgs-unstable = [ "firefox" "discord" ];
    #   nixpkgs-stable = [ "thunderbird" ];
    # };
    #
    # Add custom overlays
    # overlays.custom = [
    #   (final: prev: {
    #     firefox = prev.firefox.override {
    #       enablePlasmaBrowserIntegration = true;
    #     };
    #   })
    # ];

    services = {
      tailscale.interface = "enp5s0";

      # Traefik reverse proxy configuration
      traefik = {
        enable = lib.mkDefault true;
        enableTailscaleCerts = true; # Allow Traefik to use Tailscale's TLS certificates
        domain = "${config.networking.hostName}.mole-delta.ts.net";
        certResolver = "myresolver";

        # Enable observability
        accessLog = true; # Log all HTTP requests to journald
        metrics = true; # Export Prometheus metrics

        # Static configuration for Traefik
        staticConfigOptions = {
          log.level = "WARN";

          # Enable API and dashboard
          api = {
            dashboard = true;
            insecure = false; # Don't expose on :8080, use through entrypoint
          };

          entryPoints = {
            web = {
              address = ":80";
              http.redirections.entryPoint = {
                to = "websecure";
                scheme = "https";
              };
            };
            websecure.address = ":443";
          };
          certificatesResolvers.myresolver.tailscale = { };
        };

        # Service definitions - automatically generates routers, services, and middlewares
        services = {
          grafana = {
            backendUrl = "http://localhost:3000/";
            pathPrefix = "/grafana";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          prometheus = {
            backendUrl = "http://localhost:9090/";
            pathPrefix = "/prometheus";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };
        };

        # Additional manual configuration for Traefik dashboard
        dynamicConfigOptions = {
          http = {
            routers = {
              traefik-dashboard = {
                rule = "Host(`${config.networking.hostName}.mole-delta.ts.net`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))";
                service = "api@internal";
                entrypoints = [ "websecure" ];
                tls.certResolver = "myresolver";
              };
            };
          };
        };
      };

      nfs = {
        enable = true;
        server = {
          enable = true;
          exports = ''
            /run/media/zeno/personal/nfs-oldie 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
          '';
          openFirewall = false;
        };
      };

      # Prometheus and Grafana monitoring stack
      prometheus = {
        enable = lib.mkDefault true;
        listenAddress = "127.0.0.1"; # Only accessible via Traefik
        openFirewall = lib.mkDefault false; # No need to open firewall, using Traefik
        scrapeInterval = "15s";

        # Scrape Traefik metrics
        extraScrapeConfigs = [
          {
            job_name = "traefik";
            static_configs = [
              {
                targets = [ "localhost:8080" ]; # Traefik internal metrics port
              }
            ];
          }
        ];
      };

      grafana = {
        enable = lib.mkDefault true;
        addr = "127.0.0.1"; # Only accessible via Traefik
        openFirewall = lib.mkDefault false; # No need to open firewall, using Traefik
        domain = "${config.networking.hostName}.mole-delta.ts.net";
        subPath = "/grafana"; # Configure Grafana for subpath routing

        # Declaratively provision dashboards
        provision.dashboards = {
          "node-exporter-full" = ./dashboards/node-exporter-full.json;
        };
      };

      grafanaCloud = {
        enable = true;
        # Replace with your actual Grafana Cloud instance ID and URL
        # These are not secret values - they identify your Grafana Cloud instance
        # NB! DO NOT PUT THE API-KEY HERE!
        username = "2710025";
        remoteWriteUrl = "https://prometheus-prod-39-prod-eu-north-0.grafana.net/api/prom/push";
      };
    };

    storage = {
      filesystems = {
        enable = true;

        mounts = {
          personal = {
            device = "76177a35-e3a1-489f-9b21-88a38a0c1d3e";
            mountPoint = "personal";
            options = [ "defaults" ]; # Primary drive - no nofail
          };

          samsung = {
            device = "e7e653c3-361c-4fb2-a65e-13fdcb1e6e25";
            mountPoint = "samsung";
            options = [
              "defaults"
              "nofail"
            ]; # Secondary drive - with nofail
          };
        };

        # autoScrub.enable = true by default
        # autoScrub.interval = "weekly" by default
      };
    };
  };

  # Home Manager profiles are generated automatically. Override via telometto.home users when needed.

  # Add openrazer group to admin user for Razer device support
  users.users.${VARS.users.zeno.user}.extraGroups = VARS.users.zeno.extraGroups ++ [ "openrazer" ];

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault true;
    openrazer.enable = lib.mkDefault true;
    amdgpu.initrd.enable = lib.mkDefault true;
    graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };
  };

  # Additional services
  programs.virt-manager.enable = true;

  # System version
  system.stateVersion = "24.05";
}
