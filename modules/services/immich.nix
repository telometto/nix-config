{ lib, config, ... }:
let cfg = config.telometto.services.immich or { };
in {
  options.telometto.services.immich.enable =
    lib.mkEnableOption "Immich media server";
  options.telometto.services.immich.host = lib.mkOption {
    type = lib.types.str;
    default = "0.0.0.0";
  };
  options.telometto.services.immich.port = lib.mkOption {
    type = lib.types.port;
    default = 2283;
  };
  options.telometto.services.immich.user = lib.mkOption {
    type = lib.types.str;
    default = "immich";
  };
  options.telometto.services.immich.group = lib.mkOption {
    type = lib.types.str;
    default = "immich";
  };
  options.telometto.services.immich.secretsFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
  };
  options.telometto.services.immich.mediaLocation = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/immich";
  };
  options.telometto.services.immich.accelerationDevices = lib.mkOption {
    type = lib.types.nullOr (lib.types.listOf lib.types.str);
    default = null;
  };
  options.telometto.services.immich.openFirewall = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };
  options.telometto.services.immich.environment = lib.mkOption {
    type = lib.types.attrs;
    default = {
      IMMICH_LOG_LEVEL = "verbose";
      IMMICH_TELEMETRY_INCLUDE = "all";
    };
  };
  options.telometto.services.immich.newVersionCheck = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };
  options.telometto.services.immich.settings = lib.mkOption {
    type = lib.types.attrs;
    default = { };
  };
  options.telometto.services.immich.database = lib.mkOption {
    type = lib.types.attrs;
    default = {
      enable = true;
      createDB = true;
    };
  };
  options.telometto.services.immich.redis = lib.mkOption {
    type = lib.types.attrs;
    default = { enable = true; };
  };
  options.telometto.services.immich.ml = lib.mkOption {
    type = lib.types.attrs;
    default = {
      enable = true;
      environment = { MACHINE_LEARNING_MODEL_TTL = "600"; };
    };
  };
  options.telometto.services.immich.addVideoGroups = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description =
      "Add 'immich' service user to video/render groups (for HW accel)";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.immich = {
        enable = true;
        host = cfg.host;
        port = cfg.port;
        user = cfg.user;
        group = cfg.group;
        secretsFile = cfg.secretsFile;
        mediaLocation = cfg.mediaLocation;
        accelerationDevices = cfg.accelerationDevices;
        openFirewall = cfg.openFirewall;
        environment = cfg.environment;
        settings = lib.recursiveUpdate {
          newVersionCheck = { enabled = cfg.newVersionCheck; };
        } cfg.settings;
        database = cfg.database;
        redis = cfg.redis;
        machine-learning = cfg.ml;
      };
    }

    (lib.mkIf cfg.addVideoGroups {
      users.users.${cfg.user}.extraGroups = [ "video" "render" ];
    })
  ]);
}
