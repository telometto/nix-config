{
  lib,
  config,
  VARS,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ];

  networking = {
    hostName = lib.mkForce "blizzard";
    hostId = lib.mkForce "86bc16e3";

    firewall = rec {
      enable = true;

      allowedTCPPorts = [ ];
      allowedUDPPorts = allowedTCPPorts;

      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
  };

  ## Nemsepaced modules
  telometto = {
    # Enable server role (provides server defaults)
    role.server.enable = true;

    users.zeno.enable = true;

    # overlays.fromInputs = {
    #   nixpkgs-unstable = [ "intel-graphics-compiler" ];
    #   # nixpkgs-stable = [ "thunderbird" ];
    # };

    services = {
      tailscale = {
        interface = "enp8s0";
        openFirewall = true;

        extraUpFlags = [
          "--reset"
          "--ssh"
          "--advertise-routes=192.168.2.0/24,192.168.3.0/24"
        ];
      };

      # Enable NFS (owner module) and run as a server
      nfs = {
        enable = false; # matches legacy default (server block kept for quick flip)
        server = {
          enable = true;
          exports = ''
            /rpool/enc/transfers 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
          '';
        };
      };

      # ZFS helpers and snapshot management
      zfs.enable = true;

      # Sanoid: rely on module default template "production" (autoprune=false) and just declare datasets
      sanoid = {
        enable = false;
        datasets = {
          flash = {
            useTemplate = [ "production" ];
            recursive = "zfs";
          };

          rpool = {
            useTemplate = [ "production" ];
            recursive = "zfs";
          };

          tank = {
            useTemplate = [ "production" ];
            recursive = "zfs";
          };
        };
      };

      # Monitoring and admin UIs
      scrutiny = {
        enable = true;
        port = 11001;
        openFirewall = true;

        # Exposed via Cloudflare only: scrutiny.mydomain.com → scrutiny at root (/)
        reverseProxy = {
          enable = true;
          domain = "scrutiny.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      cockpit = {
        enable = false;
        port = 11006;
        openFirewall = true;
      };

      # Prometheus exporters
      prometheusExporters = {
        zfs = {
          enable = true;
          pools = [
            "rpool"
            "tank"
          ]; # Monitor these ZFS pools
        };
      };

      # Prometheus and Grafana monitoring stack
      prometheus = {
        enable = true;
        listenAddress = "127.0.0.1"; # Only accessible via Traefik
        openFirewall = false; # No need to open firewall, using Traefik
        scrapeInterval = "5s";

        # Scrape Traefik, ZFS, and K3s metrics
        extraScrapeConfigs = [
          {
            job_name = "traefik";
            static_configs = [
              {
                targets = [ "localhost:8080" ]; # Traefik internal metrics port
              }
            ];
          }
          {
            job_name = "zfs";
            static_configs = [
              {
                targets = [ "localhost:9134" ]; # ZFS exporter port
              }
            ];
          }
          {
            job_name = "kubelet-metrics";
            scheme = "http";
            static_configs = [
              {
                targets = [ "127.0.0.1:10255" ]; # K3s kubelet read-only port
              }
            ];
          }
          {
            job_name = "cadvisor-metrics";
            scheme = "http";
            metrics_path = "/metrics/cadvisor";
            static_configs = [
              {
                targets = [ "127.0.0.1:10255" ]; # K3s kubelet read-only port for cAdvisor container metrics
              }
            ];
          }
          {
            job_name = "kube-state-metrics";
            scheme = "http";
            static_configs = [
              {
                targets = [ "127.0.0.1:32080" ]; # NodePort for kube-state-metrics
              }
            ];
          }
        ];
      };

      grafana = {
        enable = true;

        addr = "127.0.0.1"; # Only accessible via Traefik
        openFirewall = false; # No need to open firewall, using Traefik
        domain = "metrics.${VARS.domains.public}"; # Use Cloudflare domain
        # Remove subPath - Grafana will run at root (/)

        # Declaratively provision dashboards
        provision.dashboards = {
          "server-overview" = ./dashboards/server-overview.json;
          "zfs-overview" = ./dashboards/zfs-overview.json;
        };

        # Exposed via Cloudflare only: grafana.mydomain.com → grafana at root (/)
        reverseProxy = {
          enable = true;
          domain = "metrics.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      # Kubernetes (k3s) server
      k3s = {
        enable = true;

        extraFlags = [
          "--snapshotter native"
          "--disable traefik" # using traefik from the repo packages
          "--kubelet-arg=read-only-port=10255" # Enable read-only port for metrics
        ];
      };

      paperless = {
        enable = false;
        consumptionDirIsPublic = true;
        consumptionDir = "/rpool/enc/personal/documents";
        mediaDir = "/rpool/enc/personal/paperless-media";
      };

      actual = {
        enable = false;
        port = 11005;
      };

      firefly.enable = false; # APP_KEY_FILE via defaults

      searx = {
        enable = true;
        port = 11002;
        bind = "127.0.0.1"; # Bind to localhost only (reverse proxy required)

        # Exposed via Cloudflare only: searx.mydomain.com → searx at root (/)
        # Note: base_url and engine configuration now have sensible defaults in the module
        reverseProxy = {
          enable = true;
          domain = "search.${VARS.domains.public}";
          cfTunnel.enable = true;
        };

        # Optional: Override default settings here if needed
        # settings = {
        #   engines = [ ... ];  # Override engine configuration
        # };
      };

      immich = {
        enable = false;
        host = "0.0.0.0";
        port = 11007;
        openFirewall = true;
        mediaLocation = "/flash/enc/personal/immich-library";
        secretsFile = "/opt/sec/immich-file";
        environment = {
          IMMICH_LOG_LEVEL = "verbose";
          IMMICH_TELEMETRY_INCLUDE = "all";
        };
      };

      ombi = {
        enable = true;
        port = 11003;
        openFirewall = true;
        dataDir = "/rpool/unenc/apps/nixos/ombi";

        # Exposed via Cloudflare only: ombi.mydomain.com → ombi at root (/)
        reverseProxy = {
          enable = true;
          domain = "ombi.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      plex = {
        enable = true;
        openFirewall = true;
      };

      tautulli = {
        enable = true;
        port = 11004;
        openFirewall = true;
        dataDir = "/rpool/unenc/apps/nixos/tautulli";

        # Exposed via Cloudflare only: tautulli.mydomain.com → tautulli at root (/)
        reverseProxy = {
          enable = true;
          domain = "tautulli.${VARS.domains.public}";
          cfTunnel.enable = true; # Automatically adds to Cloudflare Tunnel ingress
        };
      };

      jellyfin = {
        enable = true;
        openFirewall = true;

        # Jellyfin via Tailscale ONLY (Cloudflare ToS forbids video streaming)
        # Access: https://blizzard.mole-delta.ts.net/jellyfin
        # Configure Base URL = "/jellyfin" in Jellyfin's Dashboard → Networking
        reverseProxy = {
          enable = true;
          pathPrefix = "/jellyfin"; # Tailscale path-based routing
          stripPrefix = false; # Jellyfin handles the /jellyfin prefix internally
        };
      };

      cloudflared = {
        enable = true;
        tunnelId = "ce54cb73-83b2-4628-8246-26955d280641";
        credentialsFile = config.telometto.secrets.cloudflaredCredentialsFile;

        # Only manual entries here - services with cfTunnel.enable automatically add themselves
        ingress = {
          # Overseerr (k3s service) - manually configured
          "requests.${VARS.domains.public}" = "http://localhost:80";
          "qb.${VARS.domains.public}" = "http://localhost:80";

          # Download Management Services (k3s)
          "ff.${VARS.domains.public}" = "http://localhost:80";
          "sab.${VARS.domains.public}" = "http://localhost:80";

          # Servarr Services (k3s)
          "subs.${VARS.domains.public}" = "http://localhost:80";
          "lingarr.${VARS.domains.public}" = "http://localhost:80";
          "indexer.${VARS.domains.public}" = "http://localhost:80";
          "movies.${VARS.domains.public}" = "http://localhost:80";
          "books.${VARS.domains.public}" = "http://localhost:80";
          "series.${VARS.domains.public}" = "http://localhost:80";
        };
      };

      # Backups: Borg (daily) - Temporarily commented out to test Traefik
      borgbackup = {
        enable = false; # Temporarily disabled to test Traefik
        jobs.homeserver = {
          paths = [ "/home/${VARS.users.zeno.user}" ];
          environment.BORG_RSH = "ssh -o 'StrictHostKeyChecking=no' -i /home/${VARS.users.zeno.user}/.ssh/borg-blizzard";
          repo = (config.telometto.secrets.borgRepo or "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo");
          compression = "zstd,8";
          startAt = "daily";

          encryption = {
            mode = "repokey-blake2";
            passCommand = "cat ${config.telometto.secrets.borgKeyFile}";
          };
        };
      };

    };

    # Virtualisation stack (podman, containers, libvirt)
    virtualisation.enable = true;

    # Client program defaults
    programs = {
      # SSH and GPG managed per-user via home-manager
      ssh.enable = false;
      mtr.enable = true;
      gnupg.enable = false;
    };
  };

  hardware.cpu.intel.updateMicrocode = true;

  # ZFS boot support (host-specific)
  boot = {
    supportedFilesystems = [ "zfs" ];
    initrd.supportedFilesystems.zfs = true;
    zfs = {
      forceImportAll = true;
      requestEncryptionCredentials = true;
      devNodes = "/dev/disk/by-id";

      extraPools = [
        # "flash" # SSD
        "tank"
        "rpool"
      ];
    };
    kernel.sysctl = {
      "net.ipv4.conf.all.src_valid_mark" = 1;
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.core.wmem_max" = 7500000;
      "net.core.rmem_max" = 7500000;
    };
  };

  systemd.network = {
    enable = lib.mkForce true;
    wait-online.enable = lib.mkForce true;
    networks."40-enp8s0" = {
      matchConfig.Name = "enp8s0";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
        IPv6PrivacyExtensions = "kernel";
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # Standard NixOS services
  services = {
    tailscale.permitCertUid = lib.mkIf config.services.traefik.enable "traefik";

    traefik = {
      enable = true;
      dataDir = "/var/lib/traefik";

      staticConfigOptions = {
        log.level = "WARN";

        # Enable API and dashboard
        api = {
          dashboard = true;
          insecure = false;
        };

        # Entry points
        entryPoints = {
          # HTTP entrypoint - redirects to HTTPS (except for Cloudflare domains)
          web.address = ":80";

          # HTTPS entrypoint for Tailscale domains
          websecure.address = ":443";
        };

        # Use Tailscale for TLS certificates
        certificatesResolvers.myresolver.tailscale = { };

        # Enable Prometheus metrics
        metrics.prometheus = {
          addEntryPointsLabels = true;
          addRoutersLabels = true;
          addServicesLabels = true;
        };
      };

      # Dynamic configuration - Traefik dashboard and Overseerr (k3s)
      dynamicConfigOptions = {
        http = {
          # Global security headers middleware
          middlewares = {
            security-headers = {
              headers = {
                # Response headers for security hardening
                customResponseHeaders = {
                  X-Content-Type-Options = "nosniff";
                  X-Frame-Options = "SAMEORIGIN";
                  X-XSS-Protection = "1; mode=block";
                  Referrer-Policy = "no-referrer";
                  Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
                };

                # Content Security Policy (adjust per service if needed)
                contentSecurityPolicy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self';";

                # HSTS (HTTP Strict Transport Security) - only for HTTPS services
                # Uncomment if using HTTPS entry points
                # stsSeconds = 31536000;  # 1 year
                # stsIncludeSubdomains = true;
                # stsPreload = true;
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

            # Overseerr (k3s service) - manually configured since it's not a telometto service
            overseerr = {
              rule = "Host(`requests.${VARS.domains.public}`)";
              service = "overseerr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            # Download Management Services (k3s)
            firefox = {
              rule = "Host(`ff.${VARS.domains.public}`)";
              service = "firefox";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            sabnzbd = {
              rule = "Host(`sab.${VARS.domains.public}`)";
              service = "sabnzbd";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            # Servarr Services (k3s)
            bazarr = {
              rule = "Host(`subs.${VARS.domains.public}`)";
              service = "bazarr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            lingarr = {
              rule = "Host(`lingarr.${VARS.domains.public}`)";
              service = "lingarr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            prowlarr = {
              rule = "Host(`indexer.${VARS.domains.public}`)";
              service = "prowlarr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            radarr = {
              rule = "Host(`movies.${VARS.domains.public}`)";
              service = "radarr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            readarr = {
              rule = "Host(`books.${VARS.domains.public}`)";
              service = "readarr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            sonarr = {
              rule = "Host(`series.${VARS.domains.public}`)";
              service = "sonarr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };
          };

          services = {
            overseerr.loadBalancer.servers = [ { url = "http://localhost:10001"; } ];
            prowlarr.loadBalancer.servers = [ { url = "http://localhost:10010"; } ];
            sonarr.loadBalancer.servers = [ { url = "http://localhost:10020"; } ];
            radarr.loadBalancer.servers = [ { url = "http://localhost:10021"; } ];
            readarr.loadBalancer.servers = [ { url = "http://localhost:10022"; } ];
            bazarr.loadBalancer.servers = [ { url = "http://localhost:10030"; } ];
            lingarr.loadBalancer.servers = [ { url = "http://localhost:10031"; } ];
            sabnzbd.loadBalancer.servers = [ { url = "http://localhost:10050"; } ];
            firefox.loadBalancer.servers = [ { url = "http://localhost:10060"; } ];
          };
        };
      };
    };
  };

  # Export kubeconfig for the admin user (used by server tooling)
  environment.variables.KUBECONFIG = "/home/${VARS.users.zeno.user}/.kube/config";

  system.stateVersion = "24.11";
}
