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

  services.tailscale.permitCertUid = "traefik"; # let traefik use tailscales tls
  #enable traefik
  services.traefik = {
    enable = true;
    staticConfigOptions = {
      log = {
        level = "WARN";
      };
      # api = { }; # enable API handler
      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entryPoint = {
            # I guess this redirects traffic from 80 (http) to port 443 (https)
            to = "websecure";
            scheme = "https";
          };
        };
        websecure = {
          address = ":443";
        };
      };
      certificatesResolvers = {
        myresolver.tailscale = { };
      };
    };

    dynamicConfigOptions = {
      http = {
        services = {
          # Host services (running on NixOS directly)
          searx.loadBalancer.servers = [ { url = "http://localhost:7777/"; } ];

          # K8s services (running in k3s cluster)
          # Note: Using the LoadBalancer IPs from kubectl output
          qbit.loadBalancer.servers = [ { url = "http://192.168.2.100:8090/"; } ];
          sabnzbd.loadBalancer.servers = [ { url = "http://192.168.2.100:8080/"; } ];
          prowlarr.loadBalancer.servers = [ { url = "http://192.168.2.100:9696/"; } ];
        };

        routers = {
          # Host service router
          searx = {
            rule = "Host(`${config.networking.hostName}.mole-delta.ts.net`) && Path(`/searx`)";
            service = "searx";
            entrypoints = [ "websecure" ];
            tls = {
              certResolver = "myresolver";
              domains = [ { main = "${config.networking.hostName}.mole-delta.ts.net"; } ];
            };
          };

          # K8s service routers
          qbit = {
            rule = "Host(`${config.networking.hostName}.mole-delta.ts.net`) && Path(`/qbit`)";
            service = "qbit";
            entrypoints = [ "websecure" ];
            tls = {
              certResolver = "myresolver";
              domains = [ { main = "${config.networking.hostName}.mole-delta.ts.net"; } ];
            };
          };

          sabnzbd = {
            rule = "Host(`${config.networking.hostName}.mole-delta.ts.net`) && Path(`/sabnzbd`)";
            service = "sabnzbd";
            entrypoints = [ "websecure" ];
            tls = {
              certResolver = "myresolver";
              domains = [ { main = "${config.networking.hostName}.mole-delta.ts.net"; } ];
            };
          };

          prowlarr = {
            rule = "Host(`${config.networking.hostName}.mole-delta.ts.net`) && Path(`/prowlarr`)";
            service = "prowlarr";
            entrypoints = [ "websecure" ];
            tls = {
              certResolver = "myresolver";
              domains = [ { main = "${config.networking.hostName}.mole-delta.ts.net"; } ];
            };
          };
        };
      };
    };
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
      k3s = {
        enable = lib.mkDefault true;
        # Disable k3s built-in Traefik since we're using NixOS Traefik as the main ingress
        extraFlags = [
          "--snapshotter native"
          "--disable traefik"
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
