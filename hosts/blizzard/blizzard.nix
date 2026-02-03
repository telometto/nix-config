{
  lib,
  config,
  VARS,
  pkgs,
  self,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
    ./monitoring.nix
    ./ups.nix
    ./microvms.nix
    ./traefik.nix
    ./crowdsec.nix
    ./k8s-services.nix
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

    nix.distributedBuilds = {
      enable = true;

      buildMachines = [
        {
          hostName = "snowfall";
          systems = [ "x86_64-linux" ];
          sshUser = "zeno";
          sshKey = "/home/zeno/.ssh/nix-build-blizzard";
          maxJobs = 16;
          speedFactor = 3;
          supportedFeatures = [
            "kvm"
            "big-parallel"
            "benchmark"
          ];
        }
      ];
    };

    overlays.fromInputs = {
      # nixpkgs-unstable = [ "intel-graphics-compiler" ];
      # nixpkgs-stable = [ "searxng" ];
    };

    services = {
      resolved.DNS = [ "10.100.0.10" ];

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
          enable = false;
          domain = "scrutiny.${VARS.domains.public}";
          cfTunnel.enable = true;
        };
      };

      cockpit = {
        enable = false;
        port = 11006;
        openFirewall = true;
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
        enable = false;

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
        enable = false;

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
        enable = false;

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

          "ombi.${VARS.domains.public}" = "http://localhost:80";
          "tautulli.${VARS.domains.public}" = "http://localhost:80";
          "git.${VARS.domains.public}" = "http://localhost:80";

          "ff.${VARS.domains.public}" = "http://localhost:80";
          "sab.${VARS.domains.public}" = "http://localhost:80";

          "subs.${VARS.domains.public}" = "http://localhost:80";
          "lingarr.${VARS.domains.public}" = "http://localhost:80";
          "indexer.${VARS.domains.public}" = "http://localhost:80";
          "movies.${VARS.domains.public}" = "http://localhost:80";
          "books.${VARS.domains.public}" = "http://localhost:80";
          "series.${VARS.domains.public}" = "http://localhost:80";

          "ssh-git.${VARS.domains.public}" = "ssh://10.100.0.16:2222";
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

    programs = {
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

  environment.variables.KUBECONFIG = "/home/${VARS.users.zeno.user}/.kube/config";

  system.stateVersion = "24.11";
}
