{
  lib,
  config,
  VARS,
  pkgs,
  self,
  ...
}:
let
  grafanaDashboards = import ../../lib/grafana-dashboards.nix { inherit lib pkgs; };
in
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

  sys = {
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

      nfs = {
        enable = true;
        server = {
          enable = true;
          openFirewall = lib.mkForce true;
          exports = ''
            /rpool/enc/transfers 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
          '';
        };
      };

      samba = {
        enable = true;

        openFirewall = true;

        shares.destroyme = {
          path = "/rpool/unenc/destroyme";
          forceUser = "zeno";
        };
      };

      # AdGuard Home now runs in MicroVM (see sys.virtualisation.microvm)
      # adguardhome.enable = false;

      zfs.enable = true;

      sanoid = {
        enable = true;

        datasets = {
          # flash = {
          #   useTemplate = [ "production" ];
          #   recursive = "zfs";
          # };

          rpool = {
            useTemplate = [ "production" ];
            recursive = true;
          };

          "rpool/unenc/media" = {
            autosnap = false;
          };

          # tank = {
          #   useTemplate = [ "production" ];
          #   recursive = "zfs";
          # };
        };
      };

      scrutiny = {
        enable = true;
        port = 11001;
        openFirewall = true;

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

      prometheusExporters = {
        node = {
          enableRapl = true;
          port = 11011;
        };

        zfs = {
          enable = true;
          port = 11013;
          pools = [
            "rpool"
            "tank"
          ];
        };
      };

      # UPS monitoring (Eaton 9130)
      ups = {
        enable = true;
        mode = "standalone";

        devices.eaton9130 = {
          driver = "usbhid-ups";
          port = "auto";
          description = "Eaton 9130 UPS";
          directives = [
            "pollinterval = 5"
          ];
        };

        # NUT user for local monitoring
        users.upsmon = {
          passwordFile = config.sys.secrets.upsmonPasswordFile;
          upsmon = "primary";
          actions = [
            "SET"
            "FSD"
          ];
          instcmds = [ "ALL" ];
        };

        monitorUser = "upsmon";
        monitorPasswordFile = config.sys.secrets.upsmonPasswordFile;

        shutdownOrder = 0;

        # Prometheus exporter for UPS metrics
        prometheusExporter = {
          enable = true;
          port = 11014;
          # Empty list doesn't work - each metric must be specified
          variables = [
            "battery.charge"
            "battery.runtime"
            "input.frequency"
            "input.voltage"
            "input.voltage.nominal"
            "outlet.1.status"
            "outlet.2.status"
            "outlet.1.switchable"
            "outlet.2.switchable"
            "outlet.1.delay.shutdown"
            "outlet.2.delay.shutdown"
            "output.current"
            "output.frequency"
            "output.voltage"
            "output.voltage.nominal"
            "ups.load"
            "ups.power"
            "ups.realpower"
            "ups.status"
            "ups.temperature"
          ];
        };
      };

      electricityPriceExporter = {
        enable = true;
        port = 11012;
        priceArea = "NO2";
      };

      # VictoriaMetrics for long-term metrics storage
      # Replaces InfluxDB + Telegraf with a simpler, more performant solution
      victoriametrics = {
        enable = true;
        # port = 11008; # default, in monitoring stack port range (11008-11014)

        # Listen on all interfaces to allow remote write from other hosts via Tailscale
        listenAddress = "0.0.0.0";
        openFirewall = true; # Allow other hosts to connect

        # Retain metrics for 1 year (adjust as needed)
        retentionPeriod = "1y";

        # Automatically configure local Prometheus remote write
        prometheusRemoteWrite.enable = true;

        # Deduplication for metrics from multiple Prometheus instances
        dedup = {
          enable = true;
          minScrapeInterval = "1ms";
        };

        # Automatically add as Grafana datasource
        grafanaDatasource = {
          enable = true;
          name = "VictoriaMetrics (Long-term)";
        };
      };

      prometheus = {
        enable = true;
        port = 11009;

        listenAddress = "127.0.0.1";
        openFirewall = false;
        scrapeInterval = "5s";

        extraScrapeConfigs = [
          {
            job_name = "traefik";
            static_configs = [
              {
                targets = [ "localhost:8080" ];
              }
            ];
          }
          {
            job_name = "zfs";
            static_configs = [
              {
                targets = [ "localhost:${toString config.sys.services.prometheusExporters.zfs.port}" ];
              }
            ];
          }
          {
            job_name = "kubelet-metrics";
            scheme = "http";
            static_configs = [
              {
                targets = [ "127.0.0.1:10255" ];
              }
            ];
          }
          {
            job_name = "cadvisor-metrics";
            scheme = "http";
            metrics_path = "/metrics/cadvisor";
            static_configs = [
              {
                targets = [ "127.0.0.1:10255" ];
              }
            ];
          }
          {
            job_name = "kube-state-metrics";
            scheme = "http";
            static_configs = [
              {
                targets = [ "127.0.0.1:32080" ];
              }
            ];
          }
          {
            job_name = "electricity-price";
            scrape_interval = "5m";
            static_configs = [
              {
                targets = [ "localhost:${toString config.sys.services.electricityPriceExporter.port}" ];
              }
            ];
          }
          {
            job_name = "ups";
            # Multi-target exporter pattern: Prometheus queries the exporter with ?target=<ups_name>
            # See: https://prometheus.io/docs/guides/multi-target-exporter/
            metrics_path = "/ups_metrics";
            static_configs = [
              {
                targets = lib.mapAttrsToList (name: _: name) config.sys.services.ups.devices;
              }
            ];
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "ups";
              }
              {
                target_label = "__address__";
                replacement = "localhost:${toString config.sys.services.ups.prometheusExporter.port}";
              }
            ];
          }
        ];
      };

      grafana = {
        enable = true;
        port = 11010;

        addr = "127.0.0.1";
        openFirewall = false;
        domain = "metrics.${VARS.domains.public}";

        provision.dashboards = {
          # Community dashboards (automatically fetched from grafana.com)
          "kubernetes-cluster" = grafanaDashboards.community.kubernetes-cluster;

          # Custom dashboards (locally maintained)
          "zfs-overview" = grafanaDashboards.custom.zfs-overview;
          "power-consumption" = grafanaDashboards.custom.power-consumption;
          "power-consumption-historical" = grafanaDashboards.custom.power-consumption-historical;
          "ups-monitoring" = grafanaDashboards.custom.ups-monitoring;
          "electricity-prices" = grafanaDashboards.custom.electricity-prices;
        };

        reverseProxy = {
          enable = true;
          domain = "metrics.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      k3s = {
        enable = true;

        extraFlags = [
          "--snapshotter native"
          "--disable traefik" # using traefik from the repo packages
          "--kubelet-arg=read-only-port=10255"
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
        dataDir = "/rpool/unenc/apps/nixos/actual";
      };

      firefly.enable = false;

      searx = {
        enable = true;

        port = 11002;
        bind = "127.0.0.1";

        reverseProxy = {
          enable = true;
          domain = "search.${VARS.domains.public}";
          cfTunnel.enable = true;
          extraMiddlewares = [ "crowdsec" ];
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

        reverseProxy = {
          enable = true;
          domain = "tautulli.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      jellyfin = {
        enable = true;

        openFirewall = true;

        reverseProxy = {
          enable = true;

          pathPrefix = "/jellyfin";
          stripPrefix = false;
        };
      };

      # Git repository management (port 11015 HTTP, 2222 SSH)
      gitea = {
        enable = true;

        port = 11015;
        openFirewall = true;

        stateDir = "/rpool/unenc/apps/nixos/gitea";
        repositoryRoot = "/rpool/unenc/apps/nixos/gitea/repositories";

        database = {
          type = "postgres";
          createDatabase = true;
        };

        lfs = {
          enable = true;

          allowPureSSH = true;

          s3Backend = {
            enable = false;
            endpoint = "${config.networking.hostName}.mole-delta.ts.net:${toString config.sys.services.seaweedfs.s3.port}";
            bucket = "gitea-lfs";
            accessKeyFile = config.sys.secrets.seaweedfsAccessKeyFile;
            secretAccessKeyFile = config.sys.secrets.seaweedfsSecretAccessKeyFile;
            serveDirect = false;
          };
        };

        disableRegistration = true;

        settings.server = {
          START_SSH_SERVER = true;

          SSH_DOMAIN = "ssh-git.${VARS.domains.public}";
          SSH_LISTEN_HOST = "127.0.0.1";
          SSH_LISTEN_PORT = 2222;

          PUBLIC_URL_DETECTION = "auto";
        };

        reverseProxy = {
          enable = true;
          domain = "git.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      seaweedfs = {
        enable = false;

        ip = "127.0.0.1";

        tailscale = {
          enable = true;
          hostname = "${config.networking.hostName}.mole-delta.ts.net";
        };

        configDir = "/rpool/unenc/apps/nixos/seaweedfs/config";

        master.dataDir = "/rpool/unenc/apps/nixos/seaweedfs/master";
        master.port = 11017;

        volume = {
          dataDir = "/rpool/unenc/apps/nixos/seaweedfs/volume";
          port = 11018;
          grpcPort = 11019;
        };

        filer = {
          dataDir = "/rpool/unenc/apps/nixos/seaweedfs/filer";
          port = 11020;
        };

        s3 = {
          port = 11021;
          auth = {
            enable = true;
            accessKeyFile = config.sys.secrets.seaweedfsAccessKeyFile;
            secretAccessKeyFile = config.sys.secrets.seaweedfsSecretAccessKeyFile;
          };
        };
        metrics.port = 11022;
      };

      cloudflared = {
        enable = true;

        tunnelId = "ce54cb73-83b2-4628-8246-26955d280641";
        credentialsFile = config.sys.secrets.cloudflaredCredentialsFile;

        ingress = {
          "requests.${VARS.domains.public}" = "http://localhost:80";

          "ff.${VARS.domains.public}" = "http://localhost:80";
          "sab.${VARS.domains.public}" = "http://localhost:80";

          "subs.${VARS.domains.public}" = "http://localhost:80";
          "lingarr.${VARS.domains.public}" = "http://localhost:80";
          "indexer.${VARS.domains.public}" = "http://localhost:80";
          "movies.${VARS.domains.public}" = "http://localhost:80";
          "books.${VARS.domains.public}" = "http://localhost:80";
          "series.${VARS.domains.public}" = "http://localhost:80";

          # Gitea HTTP is auto-configured by the Gitea module
          "ssh-git.${VARS.domains.public}" = "ssh://localhost:2222";
        };
      };

      borgbackup = {
        enable = false;

        jobs.homeserver = {
          paths = [ "/home/${VARS.users.zeno.user}" ];
          environment.BORG_RSH = "ssh -o 'StrictHostKeyChecking=no' -i /home/${VARS.users.zeno.user}/.ssh/borg-blizzard";
          repo = config.sys.secrets.borgRepo or "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo";
          compression = "zstd,8";
          startAt = "daily";

          encryption = {
            mode = "repokey-blake2";
            passCommand = "cat ${config.sys.secrets.borgKeyFile}";
          };
        };
      };

    };

    virtualisation = {
      enable = true;

      microvm = {
        enable = true;
        stateDir = "/rpool/unenc/vms";
        autostart = [
          "adguard-vm"
          "actual-vm"
        ];
        externalInterface = "enp8s0";

        vms = {
          adguard-vm.flake = self;
          actual-vm.flake = self;
        };

        expose = {
          adguard-vm = {
            ip = "10.100.0.10";

            portForward = {
              enable = true;
              ports = [
                {
                  proto = "both";
                  sourcePort = 53;
                }
                {
                  proto = "tcp";
                  sourcePort = 11016;
                } # Setup UI
              ];
            };

            cfTunnel = {
              enable = false; # Enable when ready for internet access
              ingress = {
                "adguard.${VARS.domains.public}" = "http://10.100.0.10:80";
              };
            };
          };

          actual-vm = {
            ip = "10.100.0.11";

            portForward = {
              enable = true;
              ports = [
                {
                  proto = "tcp";
                  sourcePort = 11005;
                }
              ];
            };

            cfTunnel = {
              enable = true;
              ingress = {
                "actual.${VARS.domains.public}" = "http://10.100.0.11:11005";
              };
            };
          };
        };
      };
    };

    programs = {
      ssh.enable = false;
      mtr.enable = true;
      gnupg.enable = false;
    };
  };

  hardware.cpu.intel.updateMicrocode = true;

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

      dhcpV4Config = {
        UseDNS = true;
        UseRoutes = true;
        RouteMetric = 100;
      };

      dhcpV6Config = {
        UseDNS = true;
      };

      linkConfig.RequiredForOnline = "routable";
    };
  };

  services = {
    tailscale.permitCertUid = lib.mkIf config.services.traefik.enable "traefik";

    crowdsec = {
      enable = true;

      settings = {
        lapi.credentialsFile = "/var/lib/crowdsec/state/local_api_credentials.yaml";
        capi.credentialsFile = "/var/lib/crowdsec/state/online_api_credentials.yaml";

        console = {
          tokenFile = config.sys.secrets.crowdsecConsoleTokenFile;

          configuration = {
            share_manual_decisions = true;
            share_custom = true;
            share_tainted = true;
            share_context = true;
            console_management = true;
          };
        };

        general.api.server = {
          enable = true;
          listen_uri = "127.0.0.1:8085";
        };
      };

      hub = {
        collections = [
          "crowdsecurity/linux"
          "crowdsecurity/traefik"
          "crowdsecurity/http-cve"
          "crowdsecurity/whitelist-good-actors"
        ];

        scenarios = [
          "crowdsecurity/ssh-bf"
          "crowdsecurity/ssh-slow-bf"
          "crowdsecurity/http-crawl-non_statics"
          "crowdsecurity/http-probing"
          "crowdsecurity/http-sensitive-files"
          "crowdsecurity/http-bad-user-agent"
        ];

        postOverflows = [
          "crowdsecurity/auditd-nix-wrappers-whitelist-process"
          "crowdsecurity/cdn-whitelist"
        ];
      };

      localConfig = {
        acquisitions = [
          {
            source = "journalctl";
            journalctl_filter = [
              "_SYSTEMD_UNIT=traefik.service"
            ];

            labels = {
              type = "traefik";
              service = "traefik";
              environment = "production";
            };
          }
        ];

        contexts = [
          {
            context = {
              target_host = [ "evt.Meta.http_host" ];
              target_uri = [ "evt.Meta.http_path" ];
              http_method = [ "evt.Meta.http_verb" ];
              http_status = [ "evt.Meta.http_status" ];
              user_agent = [ "evt.Meta.http_user_agent" ];
            };
          }
        ];

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
    };
  };
  /*
    # CrowdSec Firewall Bouncer - kernel-level IP blocking
    environment.etc."crowdsec/bouncers/crowdsec-firewall-bouncer.yaml".text = lib.generators.toYAML { } {
      mode = "iptables";
      update_frequency = "10s";

      log_mode = "stdout";
      log_level = "info";

      api_url = "http://127.0.0.1:8085";
      api_key = ""; # Populated from SOPS secret at runtime via ExecStartPre

      deny_action = "DROP";
      deny_log = false;

      disable_ipv4 = false;
      disable_ipv6 = false;

      iptables_chains = [
        "INPUT"
        "FORWARD"
      ];
    };

    systemd.services.crowdsec-firewall-bouncer = {
      description = "CrowdSec Firewall Bouncer";
      after = [
        "network.target"
        "crowdsec.service"
      ];
      wants = [ "crowdsec.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        # Inject the API key from SOPS into the config file before starting
        ExecStartPre = "${pkgs.bash}/bin/bash -c '${pkgs.gnused}/bin/sed -i \"s|api_key: \\\"\\\"|api_key: \\\"$(cat ${config.sys.secrets.crowdsecFirewallBouncerTokenFile})\\\"|\" /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml'";
        ExecStart = "${pkgs.crowdsec-firewall-bouncer}/bin/crowdsec-firewall-bouncer -c /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  */
  services = {
    traefik = {
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

            # Relaxed headers for Overseerr/Jellyseerr (requires Plex OAuth)
            overseerr-headers = {
              headers = {
                customResponseHeaders = {
                  X-Content-Type-Options = "nosniff";
                  X-Frame-Options = "SAMEORIGIN";
                  X-XSS-Protection = "1; mode=block";
                  Referrer-Policy = "no-referrer-when-downgrade";
                  Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
                };

                # Relaxed CSP to allow Plex OAuth flow
                contentSecurityPolicy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://plex.tv https://*.plex.tv https://*.plex.direct wss://*.plex.direct; frame-src https://app.plex.tv;";

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

            overseerr = {
              rule = "Host(`requests.${VARS.domains.public}`)";
              service = "overseerr";
              entryPoints = [ "web" ];
              middlewares = [ "overseerr-headers" ];
            };

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

  systemd.services.traefik.serviceConfig = {
    BindReadOnlyPaths = [
      config.sys.secrets.crowdsecTraefikBouncerTokenFile
    ];
  };

  environment.variables.KUBECONFIG = "/home/${VARS.users.zeno.user}/.kube/config";

  system.stateVersion = "24.11";
}
