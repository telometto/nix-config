{
  config,
  lib,
  VARS,
  pkgs,
  ...
}:
let
  grafanaDashboards = import ../../lib/grafana-dashboards.nix { inherit lib pkgs; };
in
{
  networking = {
    hostName = lib.mkForce "snowfall";
    hostId = lib.mkForce "131b6b39";

    firewall = rec {
      enable = true;

      allowedTCPPorts = [ ];
      allowedUDPPorts = allowedTCPPorts;

      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
  };

  sys = {
    role.desktop.enable = true;

    desktop.flavor = "kde";

    users = {
      zeno.enable = true;
      frankie.enable = false;
    };

    nix.distributedBuilds = {
      enable = false;

      # Expose Snowfall as a remote builder using the non-root zeno account.
      server = {
        enable = true;
        write = true;
        keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEQTcAYsH7h3NCcqoeivDFUQeVbxgLKwuyXL9zhgOYs6 nix-build-snowfall"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7+oDYCwh1WRnSNBb9W3L1mJ6ym4IfoJhKu9+EFnIuf nix-build-blizzard"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOkJDRVwne3l+YumnbTO9DSVnmaf0dmVEKbajEY6lDiA nix-build-avalanche"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFwGM9ubmw5XIOeE9U0sp2p4co/xHDpbXcMIxrewL1js nix-build-kaizer"
        ];
      };

      buildMachines = [
        {
          hostName = "blizzard";
          systems = [ "x86_64-linux" ];
          sshUser = "zeno";
          sshKey = "/home/zeno/.ssh/id_ed25519";
          maxJobs = 8;
          speedFactor = 2;
          supportedFeatures = [
            "kvm"
            "big-parallel"
          ];
        }
      ];
    };

    programs = {
      nix-ld.enable = true;
      python-venv.enable = true;
    };

    # Pull specific packages from different nixpkgs inputs
    overlays.fromInputs = {
      nixpkgs-unstable = [ "lutris" ];
      #  nixpkgs-stable = [ "vesktop" ];
    };
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
      resolved = {
        enableDNS = false;
        enableFallbackDNS = true;

        enableLLMNR = true;
        LLMNR = "resolve";
      };

      tailscale = {
        interface = "enp5s0";
        openFirewall = true;
      };

      cloudflareAccessIpUpdater = {
        enable = true;
        accountId = "1f65156829c5e18a3648609b381dec9c";
        policyId = "897e5beb-2937-448f-a444-4b51ff7479b0";
        apiTokenFile = config.sops.secrets."cloudflare/access_api_token".path;
        interval = "30min";
      };

      # Enable RAPL power monitoring for CPU
      prometheusExporters.node = {
        enableRapl = true;
        port = 11011;
      };

      # Norwegian electricity price exporter (NO2 = Sør-Norge)
      electricityPriceExporter = {
        enable = true;
        port = 11012;
        priceArea = "NO2";
      };

      /*
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
      */

      prometheus = {
        enable = lib.mkDefault true;
        port = 11009;
        listenAddress = "127.0.0.1";
        openFirewall = lib.mkDefault false;
        scrapeInterval = "15s";

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
            job_name = "electricity-price";
            static_configs = [
              {
                targets = [ "localhost:${toString config.sys.services.electricityPriceExporter.port}" ];
              }
            ];
            scrape_interval = "5m"; # Prices change hourly, no need to scrape often
          }
        ];
      };

      grafana = {
        enable = lib.mkDefault true;
        port = 11010;

        addr = "127.0.0.1";
        openFirewall = lib.mkDefault false;
        domain = "metrics2.${VARS.domains.public}";

        provision.dashboards = {
          # Community dashboards (automatically fetched from grafana.com)
          "node-exporter-full" = grafanaDashboards.community.node-exporter-full;
          # Custom dashboards
          "power-consumption" = grafanaDashboards.custom.power-consumption;
        };

        reverseProxy = {
          enable = true;
          domain = "metrics2.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      cloudflared = {
        enable = true;
        tunnelId = "8e2c0187-8e1c-4700-958f-a8276707e641";
        credentialsFile = config.sys.secrets.cloudflaredCredentialsFile;

        ingress = {
          "metrics2.${VARS.domains.public}" = "http://localhost:${toString config.sys.services.grafana.port}";
        };
      };

      grafanaCloud = {
        enable = false;

        username = "2710025";
        remoteWriteUrl = "https://prometheus-prod-39-prod-eu-north-0.grafana.net/api/prom/push";
      };

      # Remote write metrics to central VictoriaMetrics on Blizzard for long-term storage
      victoriametricsRemoteWrite = {
        enable = true;
        vmHost = "blizzard"; # Tailscale hostname
      };

      traefik = {
        enable = true;
        accessLog = true;
        metrics = true;

        dashboard = {
          enable = true;
          domain = "${config.networking.hostName}.mole-delta.ts.net";
        };

        certResolvers.myresolver.tailscale = { };
      };
    };

    storage = {
      filesystems = {
        enable = true;

        mounts = {
          personal = {
            device = "76177a35-e3a1-489f-9b21-88a38a0c1d3e";
            mountPoint = "personal";
            options = [ "defaults" ];
          };

          samsung = {
            device = "e7e653c3-361c-4fb2-a65e-13fdcb1e6e25";
            mountPoint = "samsung";
            options = [
              "defaults"
              "nofail"
            ];
          };
        };
      };
    };
  };

  users.users.${VARS.users.zeno.user}.extraGroups = VARS.users.zeno.extraGroups ++ [ "openrazer" ];

  services.rpcbind.enable = lib.mkDefault true;

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault true;

    openrazer.enable = lib.mkDefault true;

    amdgpu.initrd.enable = lib.mkDefault true;

    graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };
  };

  programs.virt-manager.enable = true;

  system.stateVersion = "24.05";
}
