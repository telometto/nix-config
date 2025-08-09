# Device-specific configurations that extend the shared base
{ config, lib, pkgs, VARS, ... }:

let mylib = import ../lib { inherit lib VARS; };
in {
  # Avalanche (Laptop) specific configuration
  avalanche = {
    hardware = {
      cpu.intel.updateMicrocode = true;
      bluetooth.enable = true;
    };

    boot = { plymouth.enable = true; };

    environment.systemPackages = with pkgs; [ ];

    networking = {
      inherit (VARS.systems.laptop) hostName hostId;
      networkmanager.enable = true;
      wireless.enable = false;
      useNetworkd = lib.mkForce false;
      useDHCP = lib.mkForce true;
    };

    # programs = { };

    # virtualisation = { };

    systemd = {
      mounts = [{
        type = "nfs";
        mountConfig.options = "rw,noatime,nofail";
        what = "192.168.2.100:/rpool/enc/transfers";
        where = "/home/zeno/Documents/mnt/server/transfers";
      }];

      automounts = [{
        wantedBy = [ "multi-user.target" ];
        automountConfig.TimeoutIdleSec = "600";
        where = "/home/zeno/Documents/mnt/server/transfers";
      }];
    };
  };

  # Snowfall (Desktop) specific configuration
  snowfall = {
    hardware = {
      cpu.amd.updateMicrocode = true;
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      amdgpu.initrd.enable = true;
      openrazer = {
        enable = true;
        users = [ VARS.users.admin.user ];
      };
      bluetooth.enable = false;
    };

    boot = {
      kernel.sysctl = {
        "fs.inotify.max_user_watches" = 655360;
        "fs.file-max" = 6815744;
      };
      plymouth.enable = true;
    };

    environment.systemPackages = with pkgs; [
      openrazer-daemon
      libnfs
      nfs-utils
      btrfs-progs
      distrobox
      distrobox-tui
      fuse3
      wineWowPackages.stable
      wineWowPackages.waylandFull
      winetricks
    ];

    networking = {
      inherit (VARS.systems.desktop) hostName hostId;
      networkmanager.enable = true;
      wireless.enable = false;
      useNetworkd = lib.mkForce false;
      useDHCP = lib.mkForce true;
    };

    systemd = {
      mounts = [{
        type = "nfs";
        mountConfig.options = "rw,noatime,nofail";
        what = "192.168.2.100:/rpool/enc/transfers";
        where = "/run/media/${VARS.users.admin.user}/personal/transfers";
      }];

      automounts = [{
        wantedBy = [ "multi-user.target" ];
        automountConfig.TimeoutIdleSec = "600";
        where = "/run/media/${VARS.users.admin.user}/personal/transfers";
      }];
    };

    fileSystems = {
      "/run/media/${VARS.users.admin.user}/personal" = {
        device = "/dev/disk/by-uuid/76177a35-e3a1-489f-9b21-88a38a0c1d3e";
        fsType = "btrfs";
        options = [ "defaults" ];
      };

      "/run/media/${VARS.users.admin.user}/samsung" = {
        device = "/dev/disk/by-uuid/e7e653c3-361c-4fb2-a65e-13fdcb1e6e25";
        fsType = "btrfs";
        options = [ "defaults" "nofail" ];
      };
    };

    services = {
      teamviewer.enable = true;
      btrfs.autoScrub = {
        enable = true;
        interval = "weekly";
        fileSystems = [
          "/run/media/${VARS.users.admin.user}/personal"
          "/run/media/${VARS.users.admin.user}/samsung"
        ];
      };
      nfs.server = {
        enable = true;
        lockdPort = 4001;
        mountdPort = 4002;
        statdPort = 4000;
        exports = ''
          /run/media/${VARS.users.admin.user}/personal/nfs-oldie 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
        '';
      };
    };
  };

  # Blizzard (Server) specific configuration
  blizzard = {
    networking = {
      inherit (VARS.systems.server) hostName hostId;
      interfaces.enp8s0.useDHCP = lib.mkForce false;
    };

    systemd.network = {
      enable = lib.mkForce true;
      wait-online.enable = lib.mkForce true;
      networks = lib.mkForce {
        "40-enp8s0" = {
          matchConfig.Name = "enp8s0";
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
            IPv6PrivacyExtensions = "kernel";
          };
          linkConfig.RequiredForOnline = "routable";
        };
      };
    };

    services = {
      plex = {
        enable = true;
        openFirewall = true;
      };

      immich = {
        enable = true;
        host = "0.0.0.0";
        openFirewall = true;
        accelerationDevices = null;
        environment = {
          IMMICH_LOG_LEVEL = "verbose";
          IMMICH_TELEMETRY_INCLUDE = "all";
        };
        settings.newVersionCheck.enabled = true;
        database = {
          enable = true;
          createDB = true;
        };
        redis.enable = true;
        machine-learning = {
          enable = true;
          environment = { MACHINE_LEARNING_MODEL_TTL = "600"; };
        };
      };

      actual = {
        enable = true;
        openFirewall = true;
        settings.port = 3838;
      };

      borgbackup.jobs.homeserver = {
        paths = "/home/${VARS.users.admin.user}";
        environment.BORG_RSH =
          "ssh -o 'StrictHostKeyChecking=no' -i /home/${VARS.users.admin.user}/.ssh/borg-blizzard";
        repo = "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo";
        compression = "zstd,8";
        startAt = "daily";
        encryption = {
          mode = "repokey-blake2";
          passCommand = "cat /opt/sec/borg-file";
        };
      };

      cockpit = {
        enable = true;
        port = 9090;
        openFirewall = true;
        settings = { WebService = { AllowUnencrypted = true; }; };
      };

      sanoid = {
        enable = true;
        templates."production" = {
          autosnap = true;
          autoprune = true;
          yearly = 4;
          monthly = 4;
          weekly = 3;
          daily = 4;
          hourly = 0;
        };
        datasets = {
          rpool = {
            useTemplate = [ "production" ];
            recursive = true;
          };
          flash = {
            useTemplate = [ "production" ];
            recursive = true;
          };
        };
      };

      scrutiny = {
        enable = true;
        openFirewall = true;
        settings = { web = { listen = { port = 8072; }; }; };
      };

      k3s = {
        enable = true;
        role = "server";
        gracefulNodeShutdown = {
          enable = false;
          shutdownGracePeriod = "1m30s";
          shutdownGracePeriodCriticalPods = "1m";
        };
        extraFlags = [ "--snapshotter native" ];
      };

      paperless = {
        enable = lib.mkForce false;
        address = "0.0.0.0";
        consumptionDirIsPublic = true;
        consumptionDir = "/rpool/enc/personal/documents";
        mediaDir = "/rpool/enc/personal/paperless-media";
        passwordFile = config.sops.secrets."general/paperlessKeyFilePath".path;
      };

      firefly-iii = {
        enable = lib.mkForce false;
        enableNginx = true;
        settings = {
          APP_ENV = "local";
          APP_KEY_FILE = "/opt/sec/ff-file";
        };
      };

      searx = {
        enable = lib.mkForce false;
        redisCreateLocally = true;
        settings = {
          server = {
            port = 7777;
            bind_address = "0.0.0.0";
            secret_key = config.sops.secrets."general/searxSecretKey".path;
          };
          search = { formats = [ "html" "json" "rss" ]; };
        };
      };
    };
  };
}
