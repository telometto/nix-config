# Device-specific configurations that extend the shared base
{ config, lib, pkgs, VARS, ... }:

let mylib = import ../lib { inherit lib VARS; };
in {
  # Avalanche (Laptop) specific configuration
  avalanche = {
    # Hardware-specific
    hardware = {
      cpu.intel.updateMicrocode = true;
      pulseaudio.enable = lib.mkForce false;
      bluetooth.enable = true;
      # steam-hardware comes from laptop profile by default
    };

    boot = { plymouth.enable = true; };

    # Audio handled by profile

    # Device-specific packages
    environment.systemPackages = with pkgs; [
      # microcode handled by hardware.cpu.intel.updateMicrocode
      # Laptop-specific tools can be added here
    ];

    networking = {
      inherit (VARS.systems.laptop) hostName hostId;
      networkmanager.enable = true;
      wireless.enable = false;
      useNetworkd = lib.mkForce false;
      useDHCP = lib.mkForce true;
      # Firewall defaults handled in shared/system.nix
    };

    # Flatpak + Flathub + XDG portal provided by shared/desktop-common.nix

    # Gaming support in profile
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
      # steam-hardware not enforced here (desktop profile/host decides)
      graphics = { enable = true; enable32Bit = true; };
      amdgpu.initrd.enable = true;
      pulseaudio.enable = lib.mkForce false;
      openrazer = { enable = true; users = [ VARS.users.admin.user ]; };
      bluetooth.enable = false;
    };

    boot = {
      kernel.sysctl = {
        "fs.inotify.max_user_watches" = 655360;
        "fs.file-max" = 6815744;
      };
      plymouth.enable = true;
    };

    # Audio handled by profile

    environment.systemPackages = with pkgs; [
      openrazer-daemon
      libnfs
      nfs-utils
      btrfs-progs
      # microcode handled by hardware.cpu.amd.updateMicrocode
      distrobox
      distrobox-tui
      fuse3
      wineWowPackages.stable
      wineWowPackages.waylandFull
      winetricks
    ];

    networking = {
      inherit (VARS.systems.desktop) hostName hostId;
      # Firewall defaults handled in shared/system.nix
      networkmanager.enable = true;
      wireless.enable = false;
      useNetworkd = lib.mkForce false;
      useDHCP = lib.mkForce true;
    };

    systemd = {
      # Flathub repo handled globally in shared/desktop-common.nix

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
      # flatpak.enable moved to shared/desktop-common.nix
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

    # XDG portal provided by shared/desktop-common.nix
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

    fileSystems = {
      "/flash/enc/personal" = { device = "flash/enc/personal"; fsType = "zfs"; };
      "/flash/enc/personal/documents" = { device = "flash/enc/personal/documents"; fsType = "zfs"; };
      "/flash/enc/personal/immich-library" = { device = "flash/enc/personal/immich-library"; fsType = "zfs"; };
      "/flash/enc/personal/photos" = { device = "flash/enc/personal/photos"; fsType = "zfs"; };
      "/flash/enc/personal/videos" = { device = "flash/enc/personal/videos"; fsType = "zfs"; };
      "/rpool/enc/personal" = { device = "rpool/enc/personal"; fsType = "zfs"; };
      "/rpool/enc/personal/documents" = { device = "rpool/enc/personal/documents"; fsType = "zfs"; };
      "/rpool/enc/personal/paperless-media" = { device = "rpool/enc/personal/paperless-media"; fsType = "zfs"; };
      "/rpool/enc/transfers" = { device = "rpool/enc/transfers"; fsType = "zfs"; };
      "/rpool/unenc/apps" = { device = "rpool/unenc/apps"; fsType = "zfs"; };
      "/rpool/unenc/apps/kubernetes" = { device = "rpool/unenc/apps/kubernetes"; fsType = "zfs"; };
      "/rpool/unenc/apps/nixos" = { device = "rpool/unenc/apps/nixos"; fsType = "zfs"; };
      "/rpool/unenc/dbs" = { device = "rpool/unenc/dbs"; fsType = "zfs"; };
      "/rpool/unenc/dbs/mysql" = { device = "rpool/unenc/dbs/mysql"; fsType = "zfs"; };
      "/rpool/unenc/dbs/psql" = { device = "rpool/unenc/dbs/psql"; fsType = "zfs"; };
      "/rpool/unenc/dbs/redis" = { device = "rpool/unenc/dbs/redis"; fsType = "zfs"; };
      "/rpool/unenc/media" = { device = "rpool/unenc/media"; fsType = "zfs"; };
      "/rpool/unenc/vms" = { device = "rpool/unenc/vms"; fsType = "zfs"; };
    };

    services = {
      plex = { enable = true; openFirewall = true; };

      immich = {
        enable = true;
        host = "0.0.0.0";
        openFirewall = true;
        accelerationDevices = null;
        environment = { IMMICH_LOG_LEVEL = "verbose"; IMMICH_TELEMETRY_INCLUDE = "all"; };
        settings.newVersionCheck.enabled = true;
        database = { enable = true; createDB = true; };
        redis.enable = true;
        machine-learning = { enable = true; environment = { MACHINE_LEARNING_MODEL_TTL = "600"; }; };
      };

      actual = { enable = true; openFirewall = true; settings.port = 3838; };

      borgbackup.jobs.homeserver = {
        paths = "/home/${VARS.users.admin.user}";
        environment.BORG_RSH =
          "ssh -o 'StrictHostKeyChecking=no' -i /home/${VARS.users.admin.user}/.ssh/borg-blizzard";
        repo = "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo";
        compression = "zstd,8";
        startAt = "daily";
        encryption = { mode = "repokey-blake2"; passCommand = "cat /opt/sec/borg-file"; };
      };

      cockpit = { enable = true; port = 9090; openFirewall = true; settings = { WebService = { AllowUnencrypted = true; }; }; };

      scrutiny = { enable = true; openFirewall = true; settings = { web = { listen = { port = 8072; }; }; }; };

      # Re-added k3s; no flannel backend
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
        enable = lib.mkForce false; # disabled per proposal
        address = "0.0.0.0";
        consumptionDirIsPublic = true;
        consumptionDir = "/rpool/enc/personal/documents";
        mediaDir = "/rpool/enc/personal/paperless-media";
        passwordFile = config.sops.secrets."general/paperlessKeyFilePath".path;
      };

      firefly-iii = {
        enable = lib.mkForce false; # disabled per proposal
        enableNginx = true;
        settings = { APP_ENV = "local"; APP_KEY_FILE = "/opt/sec/ff-file"; };
      };

      searx = {
        enable = lib.mkForce false; # disabled per proposal
        redisCreateLocally = true;
        settings = {
          server = { port = 7777; bind_address = "0.0.0.0"; secret_key = config.sops.secrets."general/searxSecretKey".path; };
          search = { formats = [ "html" "json" "rss" ]; };
        };
      };
    };

    # XDG portal provided by shared/desktop-common.nix
  };
}
