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
  };

  telometto = {
    # Enable server role (provides server defaults)
    role.server.enable = true;

    # Firewall policy via owner module (role enables it); host adds extra ports/ranges
    networking = {
      firewall = {
        # Ports ONLY accessible via Tailscale (PRIVATE VPN)
        # These are safe from both internet AND LAN (unless you're on Tailscale)
        tailscale = {
          allowedTCPPorts = [
            80 # HTTP (Traefik)
            443 # HTTPS (Traefik)
            6443 # k3s API
            111 # NFS rpcbind
            2049 # NFS
            20048 # NFS mountd
            3838 # Actual
            7777 # Searx
            8072 # Scrutiny
            9090 # Cockpit
          ];
          allowedUDPPorts = [
            111 # NFS rpcbind
            2049 # NFS
            20048 # NFS mountd
          ];
          allowedTCPPortRanges = [
            {
              from = 4000;
              to = 4002;
            }
          ];
          allowedUDPPortRanges = [
            {
              from = 4000;
              to = 4002;
            }
          ];
        };
      };
    };

    services = {
      # Private networking (enabled in legacy)
      tailscale.interface = "enp8s0";

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
          # Host services (running on NixOS directly)
          searx = {
            backendUrl = "http://localhost:7777/";
            pathPrefix = "/searx";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

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

          # K8s services (running in k3s cluster)
          qbit = {
            backendUrl = "http://192.168.2.100:8090/";
            pathPrefix = "/qbit";
            stripPrefix = true;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
              X-Forwarded-Prefix = "/qbit";
            };
          };

          sabnzbd = {
            backendUrl = "http://192.168.2.100:8080/";
            pathPrefix = "/sabnzbd";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          prowlarr = {
            backendUrl = "http://192.168.2.100:9696/";
            pathPrefix = "/prowlarr";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          firefox = {
            backendUrl = "http://192.168.2.100:3001/";
            pathPrefix = "/firefox";
            stripPrefix = true;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          radarr = {
            backendUrl = "http://192.168.2.100:7878/";
            pathPrefix = "/radarr";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          sonarr = {
            backendUrl = "http://192.168.2.100:8989/";
            pathPrefix = "/sonarr";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          readarr = {
            backendUrl = "http://192.168.2.100:8787/";
            pathPrefix = "/readarr";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          bazarr = {
            backendUrl = "http://192.168.2.100:6767/";
            pathPrefix = "/bazarr";
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
      scrutiny.enable = lib.mkDefault true; # port 8072
      cockpit.enable = lib.mkDefault false; # port 9090

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

        # Automatically provisions Prometheus datasource (handled by module)
        # Declaratively provision dashboards can be added here if needed
        # provision.dashboards = {
        #   "traefik" = ./dashboards/traefik.json;
        # };
      };

      # Kubernetes (k3s) server
      k3s = {
        enable = lib.mkDefault true;
        # Disable k3s built-in Traefik since we're using NixOS Traefik as the main ingress
        extraFlags = [
          "--snapshotter native"
          "--disable traefik" # using traefik from the repo packages
        ];
      };

      # Maintenance bundle provided by role; host can override if needed

      # Apps and media
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
        openFirewall = lib.mkDefault false;
        mediaLocation = lib.mkDefault "/flash/enc/personal/immich-library";
        secretsFile = lib.mkDefault "/opt/sec/immich-file";
        environment = {
          IMMICH_LOG_LEVEL = "verbose";
          IMMICH_TELEMETRY_INCLUDE = "all";
        };
      };

      ombi = {
        enable = lib.mkDefault true;
        dataDir = lib.mkDefault "/rpool/unenc/apps/nixos/ombi";
      };

      plex.enable = lib.mkDefault true;

      tautulli = {
        enable = lib.mkDefault true;
        dataDir = lib.mkDefault "/rpool/unenc/apps/nixos/tautulli";
      };

      jellyfin.enable = lib.mkForce false; # disabled until lidbm issue has been solved

      # Backups: Borg (daily)
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
