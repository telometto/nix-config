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
          "--advertise-routes=192.168.2.0/24,192.168.3.0/24,"
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
          # Note: Download management apps (qbit, sabnzbd, firefox) are managed by k3s-download-management-stack.nix
          # Note: Servarr apps (radarr, sonarr, lidarr, readarr, prowlarr, bazarr) are managed by k3s-servarr-stack.nix

          jellyfin = {
            backendUrl = "http://localhost:8096/";
            pathPrefix = "/jellyfin";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          ombi = {
            backendUrl = "http://localhost:5000/";
            pathPrefix = "/ombi";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          tautulli = {
            backendUrl = "http://localhost:8181/";
            pathPrefix = "/tautulli";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          scrutiny = {
            backendUrl = "http://localhost:8072/";
            pathPrefix = "/scrutiny";
            stripPrefix = false;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          cockpit = {
            backendUrl = "http://localhost:9090/";
            pathPrefix = "/cockpit";
            stripPrefix = true;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            };
          };

          homepage = {
            backendUrl = "http://localhost:8082/";
            pathPrefix = "/homepage";
            stripPrefix = true;
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

      plex = {
        enable = lib.mkDefault true;
        openFirewall = true;
      };

      tautulli = {
        enable = lib.mkDefault true;
        dataDir = lib.mkDefault "/rpool/unenc/apps/nixos/tautulli";
      };

      jellyfin = {
        enable = lib.mkDefault true;
        openFirewall = true;
      };

      # Homepage dashboard
      homepage = {
        enable = lib.mkDefault true;
        port = lib.mkDefault 8082;

        settings = {
          title = "Blizzard Home Server";
          theme = "dark";
          color = "slate";
          headerStyle = "boxed";
          hideVersion = false;
        };

        services = [
          {
            "Media Services" = [
              {
                "Plex" = {
                  icon = "plex.png";
                  href = "http://blizzard:32400/web";
                  description = "Media Server";
                  widget = {
                    type = "plex";
                    url = "http://blizzard:32400";
                    key = "{{HOMEPAGE_VAR_PLEX_TOKEN}}";
                  };
                };
              }
              {
                "Jellyfin" = {
                  icon = "jellyfin.png";
                  href = "http://blizzard:8096";
                  description = "Alternative Media Server";
                  widget = {
                    type = "jellyfin";
                    url = "http://blizzard:8096";
                    key = "{{HOMEPAGE_VAR_JELLYFIN_TOKEN}}";
                  };
                };
              }
              {
                "Ombi" = {
                  icon = "ombi.png";
                  href = "http://blizzard:5000";
                  description = "Request Movies & TV Shows";
                  widget = {
                    type = "ombi";
                    url = "http://blizzard:5000";
                    key = "{{HOMEPAGE_VAR_OMBI_TOKEN}}";
                  };
                };
              }
              {
                "Tautulli" = {
                  icon = "tautulli.png";
                  href = "http://blizzard:8181";
                  description = "Plex Statistics";
                  widget = {
                    type = "tautulli";
                    url = "http://blizzard:8181";
                    key = "{{HOMEPAGE_VAR_TAUTULLI_TOKEN}}";
                  };
                };
              }
            ];
          }
          {
            "Download & Indexing" = [
              {
                "qBittorrent" = {
                  icon = "qbittorrent.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/qbit";
                  description = "Torrent Client";
                  widget = {
                    type = "qbittorrent";
                    url = "http://192.168.2.100:8090";
                  };
                };
              }
              {
                "SABnzbd" = {
                  icon = "sabnzbd.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/sabnzbd";
                  description = "Usenet Client";
                  widget = {
                    type = "sabnzbd";
                    url = "http://192.168.2.100:8080";
                    key = "{{HOMEPAGE_VAR_SABNZBD_TOKEN}}";
                  };
                };
              }
              {
                "Prowlarr" = {
                  icon = "prowlarr.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/prowlarr";
                  description = "Indexer Manager";
                  widget = {
                    type = "prowlarr";
                    url = "http://192.168.2.100:9696";
                    key = "{{HOMEPAGE_VAR_PROWLARR_TOKEN}}";
                  };
                };
              }
            ];
          }
          {
            "Media Management" = [
              {
                "Sonarr" = {
                  icon = "sonarr.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/sonarr";
                  description = "TV Show Management";
                  widget = {
                    type = "sonarr";
                    url = "http://192.168.2.100:8989";
                    key = "{{HOMEPAGE_VAR_SONARR_TOKEN}}";
                  };
                };
              }
              {
                "Radarr" = {
                  icon = "radarr.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/radarr";
                  description = "Movie Management";
                  widget = {
                    type = "radarr";
                    url = "http://192.168.2.100:7878";
                    key = "{{HOMEPAGE_VAR_RADARR_TOKEN}}";
                  };
                };
              }
              {
                "Readarr" = {
                  icon = "readarr.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/readarr";
                  description = "Book Management";
                  widget = {
                    type = "readarr";
                    url = "http://192.168.2.100:8787";
                    key = "{{HOMEPAGE_VAR_READARR_TOKEN}}";
                  };
                };
              }
              {
                "Bazarr" = {
                  icon = "bazarr.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/bazarr";
                  description = "Subtitle Management";
                  widget = {
                    type = "bazarr";
                    url = "http://192.168.2.100:6767";
                    key = "{{HOMEPAGE_VAR_BAZARR_TOKEN}}";
                  };
                };
              }
            ];
          }
          {
            "Monitoring & Admin" = [
              {
                "Grafana" = {
                  icon = "grafana.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/grafana";
                  description = "Monitoring Dashboards";
                };
              }
              {
                "Prometheus" = {
                  icon = "prometheus.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/prometheus";
                  description = "Metrics Database";
                };
              }
              {
                "Traefik" = {
                  icon = "traefik.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/dashboard/";
                  description = "Reverse Proxy";
                  widget = {
                    type = "traefik";
                    url = "http://localhost:8080";
                  };
                };
              }
              {
                "Scrutiny" = {
                  icon = "scrutiny.png";
                  href = "http://blizzard:8072";
                  description = "Drive Health Monitor";
                };
              }
            ];
          }
          {
            "Utilities" = [
              {
                "SearX" = {
                  icon = "searxng.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/searx";
                  description = "Private Search Engine";
                };
              }
              {
                "Firefox" = {
                  icon = "firefox.png";
                  href = "https://${config.networking.hostName}.mole-delta.ts.net/firefox";
                  description = "Remote Browser";
                };
              }
            ];
          }
        ];

        widgets = [
          {
            resources = {
              cpu = true;
              memory = true;
              disk = "/";
              uptime = true;
            };
          }
          {
            search = {
              provider = "custom";
              url = "https://${config.networking.hostName}.mole-delta.ts.net/searx/search?q=";
              target = "_blank";
            };
          }
        ];

        bookmarks = [
          {
            "Quick Links" = [
              {
                "GitHub" = [
                  {
                    abbr = "GH";
                    href = "https://github.com";
                  }
                ];
              }
              {
                "NixOS Manual" = [
                  {
                    abbr = "NX";
                    href = "https://nixos.org/manual/nixos/stable/";
                  }
                ];
              }
            ];
          }
        ];
      };

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

  # Direct CrowdSec configuration (bypassing wrapper module)
  services.crowdsec = {
    enable = true;

    # Hub collections and scenarios
    hub = {
      collections = [
        "crowdsecurity/linux"
        "crowdsecurity/traefik"
      ];
      scenarios = [
        "crowdsecurity/ssh-bf"
        "crowdsecurity/ssh-slow-bf"
      ];
      postOverflows = [
        "crowdsecurity/auditd-nix-wrappers-whitelist-process"
      ];
    };

    # Data sources
    localConfig = {
      acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels = {
            type = "syslog";
          };
        }
      ];

      # Default profile for IP bans
      profiles = [
        {
          name = "default_ip_remediation";
          filters = [ "Alert.Remediation == true && Alert.GetScope() == 'Ip'" ];
          decisions = [
            {
              type = "ban";
              duration = "4h";
            }
          ];
          on_success = "break";
        }
      ];
    };

    # Settings - let upstream handle credential files
    settings = {
      ## TESTING
      # Don't set api.client.credentials_path - let it use the default
      # Don't set lapi.credentialsFile - let it use the default
      # Don't set capi.credentialsFile - we don't have CAPI credentials
      # Don't set console.tokenFile - we're not using console

      simulation = {
        simulation = false;
      };
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
