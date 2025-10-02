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
        enable = true;
        extraTCPPortRanges = [
          {
            from = 4000;
            to = 4002;
          }
        ];
        extraUDPPortRanges = [
          {
            from = 4000;
            to = 4002;
          }
        ];
        # Include service ports for k3s, HTTP/HTTPS, NFS, Paperless, Actual, Searx, Scrutiny, Cockpit
        extraTCPPorts = [
          6443
          80
          443
          111
          2049
          20048
          28981
          3838
          7777
          8072
          9090
        ];
        extraUDPPorts = [
          6443
          80
          443
          111
          2049
          20048
          28981
          3838
          7777
          8072
          9090
        ];
      };
    };

    services = {
      # Private networking (enabled in legacy)
      tailscale = {
        enable = lib.mkDefault true;
        interface = "enp8s0"; # Overrides the interface for this host
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
      ssh.enable = lib.mkDefault true;
      mtr.enable = lib.mkDefault true;
      gnupg.enable = lib.mkDefault true;
    };
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;

  # ZFS boot support (host-specific)
  boot = {
    supportedFilesystems = [ "zfs" ];
    initrd.supportedFilesystems.zfs = true;
    zfs = {
      enabled = true;
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
