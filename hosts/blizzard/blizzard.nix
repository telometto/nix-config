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

  # Standard NixOS services
  services.traefik = {
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
        routers = {
          traefik-dashboard = {
            rule = "Host(`${config.networking.hostName}.mole-delta.ts.net`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))";
            service = "api@internal";
            entryPoints = [ "websecure" ];
            tls.certResolver = "myresolver";
          };

          # Overseerr (k3s service) - manually configured since it's not a telometto service
          overseerr = {
            rule = "Host(`requests.${VARS.domains.public}`)";
            service = "overseerr";
            entryPoints = [ "web" ];
          };
        };

        services = {
          # Overseerr (k3s service)
          overseerr = {
            loadBalancer = {
              servers = [
                { url = "http://localhost:5055"; }
              ];
            };
          };
        };
      };
    };
  };

  #Allow Traefik to use Tailscale certificates
  services.tailscale.permitCertUid = "traefik";

  telometto = {
    # Enable server role (provides server defaults)
    role.server.enable = true;

    users.zeno.enable = true;

    # overlays.fromInputs = {
    #   nixpkgs-unstable = [ "intel-graphics-compiler" ];
    #   # nixpkgs-stable = [ "thunderbird" ];
    # };

    services = {
      # Private networking (enabled in legacy)
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
        enable = lib.mkDefault false; # matches legacy default (server block kept for quick flip)
        server = {
          enable = true;
          exports = ''
            /rpool/enc/transfers 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
          '';
        };
      };

      # ZFS helpers and snapshot management
      zfs.enable = lib.mkDefault true;

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
        enable = lib.mkDefault true; # port 8072
        openFirewall = true;

        # Exposed via Cloudflare only: scrutiny.mydomain.com → scrutiny at root (/)
        reverseProxy = {
          enable = true;
          domain = "scrutiny.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      cockpit = {
        enable = lib.mkDefault false; # port 9090
        openFirewall = true;
      };

      # Prometheus exporters
      prometheusExporters = {
        zfs = {
          enable = lib.mkDefault true;
          pools = [
            "rpool"
            "tank"
          ]; # Monitor these ZFS pools
        };
      };

      # Prometheus and Grafana monitoring stack
      prometheus = {
        enable = lib.mkDefault true;
        listenAddress = "127.0.0.1"; # Only accessible via Traefik
        openFirewall = lib.mkDefault false; # No need to open firewall, using Traefik
        scrapeInterval = "15s";

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
                targets = [ "127.0.0.1:30080" ]; # NodePort for kube-state-metrics
              }
            ];
          }
        ];
      };

      grafana = {
        enable = lib.mkDefault true;
        addr = "127.0.0.1"; # Only accessible via Traefik
        openFirewall = lib.mkDefault false; # No need to open firewall, using Traefik
        domain = "grafana.${VARS.domains.public}"; # Use Cloudflare domain
        # Remove subPath - Grafana will run at root (/)

        # Declaratively provision dashboards
        provision.dashboards = {
          "server-overview" = ./dashboards/server-overview.json;
          "zfs-overview" = ./dashboards/zfs-overview.json;
        };

        # Exposed via Cloudflare only: grafana.mydomain.com → grafana at root (/)
        reverseProxy = {
          enable = true;
          domain = "grafana.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      # Kubernetes (k3s) server
      k3s = {
        enable = lib.mkDefault true;
        # Disable k3s built-in Traefik since we're using NixOS Traefik as the main ingress
        extraFlags = [
          "--snapshotter native"
          "--disable traefik" # using traefik from the repo packages
          "--kubelet-arg=read-only-port=10255" # Enable read-only port for metrics
        ];
      };

      paperless = {
        enable = lib.mkDefault false;
        consumptionDirIsPublic = lib.mkDefault true;
        consumptionDir = lib.mkDefault "/rpool/enc/personal/documents";
        mediaDir = lib.mkDefault "/rpool/enc/personal/paperless-media";
      };

      actual = {
        enable = lib.mkDefault false; # port 3838
        port = lib.mkDefault 3838;
      };

      firefly.enable = lib.mkDefault false; # APP_KEY_FILE via defaults

      searx = {
        enable = lib.mkDefault true; # port 7777 bind 0.0.0.0
        port = lib.mkDefault 7777;
        # Update base_url for Cloudflare domain (not Tailscale)
        settings.server.base_url = "https://searx.${VARS.domains.public}/";

        # Exposed via Cloudflare only: searx.mydomain.com → searx at root (/)
        reverseProxy = {
          enable = true;
          domain = "searx.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      immich = {
        enable = lib.mkDefault false;
        host = lib.mkDefault "0.0.0.0";
        port = lib.mkDefault 2283;
        openFirewall = true;
        mediaLocation = lib.mkDefault "/flash/enc/personal/immich-library";
        secretsFile = lib.mkDefault "/opt/sec/immich-file";
        environment = {
          IMMICH_LOG_LEVEL = "verbose";
          IMMICH_TELEMETRY_INCLUDE = "all";
        };
      };

      ombi = {
        enable = lib.mkDefault true;
        openFirewall = true;
        dataDir = lib.mkDefault "/rpool/unenc/apps/nixos/ombi";

        # Exposed via Cloudflare only: ombi.mydomain.com → ombi at root (/)
        reverseProxy = {
          enable = true;
          domain = "ombi.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      plex = {
        enable = lib.mkDefault true;
        openFirewall = true;
      };

      tautulli = {
        enable = lib.mkDefault true;
        openFirewall = true;
        dataDir = lib.mkDefault "/rpool/unenc/apps/nixos/tautulli";

        # Exposed via Cloudflare only: tautulli.mydomain.com → tautulli at root (/)
        reverseProxy = {
          enable = true;
          domain = "tautulli.${VARS.domains.public}";
          cfTunnel.enable = true; # Automatically adds to Cloudflare Tunnel ingress
        };
      };

      jellyfin = {
        enable = lib.mkDefault true;
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
        enable = lib.mkDefault true;
        tunnelId = "ce54cb73-83b2-4628-8246-26955d280641";
        credentialsFile = config.telometto.secrets.cloudflaredCredentialsFile;

        # Only manual entries here - services with cfTunnel.enable automatically add themselves
        ingress = {
          # Overseerr (k3s service) - manually configured
          "requests.${VARS.domains.public}" = "http://localhost:80";
        };
      };

      # Backups: Borg (daily) - Temporarily commented out to test Traefik
      borgbackup = {
        enable = lib.mkDefault false; # Temporarily disabled to test Traefik
        jobs.homeserver = {
          paths = [ "/home/${VARS.users.zeno.user}" ];
          environment.BORG_RSH = "ssh -o 'StrictHostKeyChecking=no' -i /home/${VARS.users.zeno.user}/.ssh/borg-blizzard";
          repo = lib.mkDefault (
            config.telometto.secrets.borgRepo or "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo"
          );
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
    virtualisation.enable = lib.mkDefault true;

    # Client program defaults
    programs = {
      # SSH and GPG managed per-user via home-manager
      ssh.enable = lib.mkDefault false;
      mtr.enable = lib.mkDefault true;
      gnupg.enable = lib.mkDefault false;
    };
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;

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

  # Export kubeconfig for the admin user (used by server tooling)
  environment.variables.KUBECONFIG = "/home/${VARS.users.zeno.user}/.kube/config";

  system.stateVersion = "24.11";
}
