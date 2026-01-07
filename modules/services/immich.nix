{ lib, config, ... }:
let
  cfg = config.sys.services.immich or { };
in
{
  options.sys.services.immich = {
    enable = lib.mkEnableOption "Immich media server";

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "immich";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "immich";
    };

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };

    mediaLocation = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/immich";
    };

    accelerationDevices = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    environment = lib.mkOption {
      type = lib.types.attrs;
      default = {
        IMMICH_LOG_LEVEL = "verbose";
        IMMICH_TELEMETRY_INCLUDE = "all";
      };
    };

    newVersionCheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };

    database = lib.mkOption {
      type = lib.types.attrs;
      default = {
        enable = true;
        createDB = true;
      };
    };

    redis = lib.mkOption {
      type = lib.types.attrs;
      default = {
        enable = true;
      };
    };

    ml = lib.mkOption {
      type = lib.types.attrs;
      default = {
        enable = true;
        environment = {
          MACHINE_LEARNING_MODEL_TTL = "600";
        };
      };
    };

    addVideoGroups = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add 'immich' service user to video/render groups (for HW accel)";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.immich = {
          enable = lib.mkDefault true;
          inherit (cfg)
            host
            port
            user
            group
            secretsFile
            mediaLocation
            accelerationDevices
            openFirewall
            environment
            database
            redis
            ;

          settings = lib.recursiveUpdate {
            newVersionCheck = {
              enabled = lib.mkDefault cfg.newVersionCheck;
            };
          } cfg.settings;
          machine-learning = cfg.ml;
        };
      }

      (lib.mkIf cfg.addVideoGroups {
        users.users.${cfg.user}.extraGroups = [
          "video"
          "render"
        ];
      })
    ]
  );
}
