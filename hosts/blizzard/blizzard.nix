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
        domain = "${config.networking.hostName}.mole-delta.ts.net";
        subPath = "/grafana"; # Configure Grafana for subpath routing

        # Declaratively provision dashboards
        provision.dashboards = {
          "server-overview" = ./dashboards/server-overview.json;
          "zfs-overview" = ./dashboards/zfs-overview.json;
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
        settings.server.base_url = "https://${config.networking.hostName}.mole-delta.ts.net/searx/";
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
      };

      plex = {
        enable = lib.mkDefault true;
        openFirewall = true;
      };

      tautulli = {
        enable = lib.mkDefault true;
        openFirewall = true;
        dataDir = lib.mkDefault "/rpool/unenc/apps/nixos/tautulli";

        # Configure for both Tailscale (path-based) and Cloudflare (domain-based) access
        reverseProxy = {
          enable = true;
          domain = "tautulli.${VARS.domains.public}"; # Cloudflare subdomain routing
          pathPrefix = "/tautulli"; # Tailscale path-based routing
        };
      };

      jellyfin = {
        enable = lib.mkDefault true;
        openFirewall = true;
      };

      # Cloudflare Tunnel - Expose services to the internet
      # Architecture: Internet → Cloudflare → Tunnel → Traefik → Service
      #
      # Cloudflare Tunnel Configuration (Zero Trust Dashboard):
      #   Service Type: HTTPS
      #   URL: https://localhost:443
      #   TLS Verification: Enabled (Traefik uses Tailscale certs)
      #   No-TLS-Verify: false (keep TLS verification on)
      #
      # Traefik handles routing based on Host header from Cloudflare
      # All traffic routes through Traefik for centralized auth, logging, and TLS
      cloudflared = {
        enable = lib.mkDefault true;
        tunnelId = "a1820b85-c1ca-4217-b31b-ca6ca5fce7d9";
        credentialsFile = config.telometto.secrets.cloudflaredCredentialsFile;

        ingress = {
          # Route everything through Traefik - it will handle service routing by hostname
          # Each service configured here needs corresponding DNS record in Cloudflare
          "tautulli.${VARS.domains.public}" = "https://localhost:443";

          # Monitoring
          # "grafana.yourdomain.com" = "https://localhost:443";

          # Search engine
          # "searx.yourdomain.com" = "https://localhost:443";

          # Media management (excluding Plex/Jellyfin per Cloudflare ToS)
          # "ombi.yourdomain.com" = "https://localhost:443";

          # System monitoring
          # "scrutiny.yourdomain.com" = "https://localhost:443";
          # "cockpit.yourdomain.com" = "https://localhost:443";
        };
      }; # Backups: Borg (daily)
      borgbackup = {
        enable = lib.mkDefault true;
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
