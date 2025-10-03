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
    domain = "mole-delta.ts.net"; # Your Tailscale domain
  };

  telometto = {
    # Enable server role (provides server defaults)
    role.server.enable = true;

    # Firewall policy via owner module (role enables it); host adds extra ports/ranges
    networking = {
      firewall = {
        enable = true;

        # Ports accessible from anywhere (PUBLIC INTERNET)
        # Only put ports here that MUST be accessible from outside Tailscale
        extraTCPPorts = [
          # SSH is typically already allowed by services.openssh.openFirewall
          # Add other public-facing services here if needed
        ];
        extraUDPPorts = [ ];
        
        extraTCPPortRanges = [ ];
        extraUDPPortRanges = [ ];

        # LAN-only access (COMMENTED OUT - Using Tailscale-only for security)
        # Note: Interface-specific rules on the same physical interface that handles
        # internet traffic will expose ports to BOTH LAN and internet.
        # Use Tailscale for secure, private access instead.
        # lan = {
        #   interface = "enp8s0";  # Your network interface
        #   allowedTCPPorts = [
        #     80    # HTTP (Traefik) - accessible from LAN
        #     443   # HTTPS (Traefik) - accessible from LAN
        #     8096  # Jellyfin direct (optional, if you want to bypass Traefik from LAN)
        #   ];
        #   allowedTCPPortRanges = [ ];
        #   allowedUDPPortRanges = [ ];
        # };

        # Ports ONLY accessible via Tailscale (PRIVATE VPN)
        # These are safe from both internet AND LAN (unless you're on Tailscale)
        tailscale = {
          allowedTCPPorts = [
            80    # HTTP (Traefik)
            443   # HTTPS (Traefik)
            6443  # k3s API
            111   # NFS rpcbind
            2049  # NFS
            20048 # NFS mountd
            28981 # Service port
            3838  # Actual
            7777  # Searx
            8072  # Scrutiny
            9090  # Cockpit
          ];
          allowedUDPPorts = [
            111   # NFS rpcbind
            2049  # NFS
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
      tailscale = {
        enable = lib.mkDefault true;
        interface = "enp8s0"; # Overrides the interface for this host
      };

      traefik = {
        enable = true;

        staticConfigOptions = {
          # Define entrypoints for HTTP and HTTPS
          # Firewall restricts these to Tailscale network only
          entryPoints = {
            web = {
              address = ":80";
            };
            websecure = {
              address = ":443";
            };
          };

          # Enable API and dashboard (accessible at https://blizzard.tailXXXX.ts.net:8080/dashboard/)
          # api = {
          #   dashboard = true;
          #   insecure = false; # Set to for access to dashboard without auth on :8080
          # };

          # Enable access logs for debugging
          log.level = "INFO";

          # File provider for dynamic configuration
          providers = {
            file = {
              filename = "${config.services.traefik.dataDir}/dynamic.toml";
              watch = true;
            };
          };
        };

        dynamicConfigOptions = {
          # TLS configuration using Tailscale certificates
          tls = {
            certificates = [
              {
                certFile = "/opt/sec/certs/${config.networking.hostName}.${config.networking.domain}.crt";
                keyFile = "/opt/sec/certs/${config.networking.hostName}.${config.networking.domain}.key";
              }
            ];
          };

          # HTTP routers and services
          http = {
            routers = {
              # Root domain redirects to Jellyfin (or you can make a landing page)
              root-redirect = {
                rule = "Host(`${config.networking.hostName}.${config.networking.domain}`) && Path(`/`)";
                entryPoints = [ "websecure" ];
                service = "jellyfin";
                middlewares = [ "jellyfin-headers" ];
                tls = { };
              };

              # Jellyfin at /jellyfin
              jellyfin-secure = {
                rule = "Host(`${config.networking.hostName}.${config.networking.domain}`) && PathPrefix(`/jellyfin`)";
                entryPoints = [ "websecure" ];
                service = "jellyfin";
                middlewares = [ "jellyfin-headers" "strip-jellyfin-prefix" ];
                tls = { };
              };

              # Plex at /plex (example for adding more services)
              # plex-secure = {
              #   rule = "Host(`${config.networking.hostName}.${config.networking.domain}`) && PathPrefix(`/plex`)";
              #   entryPoints = [ "websecure" ];
              #   service = "plex";
              #   middlewares = [ "strip-plex-prefix" ];
              #   tls = { };
              # };

              # Ombi at /ombi (example)
              # ombi-secure = {
              #   rule = "Host(`${config.networking.hostName}.${config.networking.domain}`) && PathPrefix(`/ombi`)";
              #   entryPoints = [ "websecure" ];
              #   service = "ombi";
              #   middlewares = [ "strip-ombi-prefix" ];
              #   tls = { };
              # };

              # HTTP to HTTPS redirect for all services
              http-redirect = {
                rule = "Host(`${config.networking.hostName}.${config.networking.domain}`)";
                entryPoints = [ "web" ];
                middlewares = [ "redirect-to-https" ];
                service = "jellyfin"; # Dummy service, won't be reached
              };
            };

            services = {
              jellyfin.loadBalancer.servers = [ { url = "http://localhost:8096"; } ];
              # plex.loadBalancer.servers = [ { url = "http://localhost:32400"; } ];
              # ombi.loadBalancer.servers = [ { url = "http://localhost:3579"; } ];
            };

            # Middlewares
            middlewares = {
              redirect-to-https.redirectScheme = {
                scheme = "https";
                permanent = true;
              };

              # Strip /jellyfin prefix before forwarding to backend
              strip-jellyfin-prefix.stripPrefix.prefixes = [ "/jellyfin" ];

              # Add more strip-prefix middlewares for other services
              # strip-plex-prefix.stripPrefix.prefixes = [ "/plex" ];
              # strip-ombi-prefix.stripPrefix.prefixes = [ "/ombi" ];

              # Headers for Jellyfin to work correctly behind reverse proxy
              jellyfin-headers.headers.customRequestHeaders = {
                X-Forwarded-Proto = "https";
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

      # Kubernetes (k3s) server
      k3s.enable = lib.mkDefault true;

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
      };

      immich = {
        enable = lib.mkDefault false;
        host = lib.mkDefault "0.0.0.0";
        port = lib.mkDefault 2283;
        openFirewall = lib.mkDefault true;
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

      jellyfin.enable = lib.mkDefault true;

      # Backups: Borg (daily)
      borgbackup = {
        enable = lib.mkDefault true;
        jobs.homeserver = {
          paths = [ "/home/${VARS.users.admin.user}" ];
          environment.BORG_RSH = "ssh -o 'StrictHostKeyChecking=no' -i /home/${VARS.users.admin.user}/.ssh/borg-blizzard";
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
  environment.variables.KUBECONFIG = "/home/${VARS.users.admin.user}/.kube/config";

  system.stateVersion = "24.11";
}
