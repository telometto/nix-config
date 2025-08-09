# Blizzard (Server) device module
{ config, lib, pkgs, VARS, ... }:
let
  adminUser = VARS.users.admin.user;
  constants = import ../shared/constants.nix;
  lanCIDR = constants.network.lanCIDR;
in {
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
    plex.enable = true; services.plex.openFirewall = true; # ensure openFirewall

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
      database = { enable = true; createDB = true; };
      redis.enable = true;
      machine-learning = { enable = true; environment = { MACHINE_LEARNING_MODEL_TTL = "600"; }; };
    };

    actual = { enable = true; openFirewall = true; settings.port = 3838; };

    cockpit = {
      enable = true;
      port = 9090;
      openFirewall = true;
      settings = { WebService = { AllowUnencrypted = true; }; };
    };

    sanoid = {
      enable = true;
      templates."production" = {
        autosnap = true; autoprune = true; yearly = 4; monthly = 4; weekly = 3; daily = 4; hourly = 0;
      };
      datasets = {
        rpool = { useTemplate = [ "production" ]; recursive = true; };
        flash = { useTemplate = [ "production" ]; recursive = true; };
      };
    };

    scrutiny = { enable = true; openFirewall = true; settings = { web.listen.port = 8072; }; };

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
      settings = { APP_ENV = "local"; APP_KEY_FILE = "/opt/sec/ff-file"; };
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
        search.formats = [ "html" "json" "rss" ];
      };
    };
  };

  # Borg backup job will be migrated to my.backups in shared or host-specific config
}
