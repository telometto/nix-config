{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.seaweedfs;
in
{
  options.services.seaweedfs = {
    enable = mkEnableOption "SeaweedFS S3 object storage";

    package = mkPackageOption pkgs "seaweedfs" { };

    configDir = mkOption {
      type = types.path;
      default = "/var/lib/seaweedfs/config";
      description = "Directory for SeaweedFS configuration files (s3.config.json, etc)";
    };

    master = {
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/seaweedfs/master";
        description = "Directory for master metadata";
      };

      metricsAddress = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Prometheus gateway address for metrics";
      };
    };

    volume = {
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/seaweedfs/volume";
        description = "Directory for volume data";
      };

      maxSize = mkOption {
        type = types.int;
        default = 0;
        description = "Max number of volumes (0 = unlimited)";
      };

      maxVolumeSizeMb = mkOption {
        type = types.int;
        default = 1024;
        description = "Maximum volume size in MB for single-node setup";
      };
    };

    ip = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IP address to bind to";
    };

    s3.enable = mkEnableOption "S3 API support" // {
      default = true;
    };

    s3.port = mkOption {
      type = types.port;
      default = 8333;
      description = "S3 API server port";
    };

    filer = {
      enable = mkEnableOption "Filer service" // {
        default = true;
      };

      port = mkOption {
        type = types.port;
        default = 8888;
        description = "Filer server port";
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/seaweedfs/filer";
        description = "Directory for filer metadata (leveldb)";
      };
    };

    tailscale = {
      enable = mkEnableOption "bind to Tailscale interface";

      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Tailscale hostname/IP to bind S3 to (if different from main ip)";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.master.dataDir != "";
        message = "services.seaweedfs.master.dataDir must not be empty";
      }
      {
        assertion = cfg.volume.dataDir != "";
        message = "services.seaweedfs.volume.dataDir must not be empty";
      }
      {
        assertion = !cfg.tailscale.enable || cfg.tailscale.hostname != null;
        message = "services.seaweedfs.tailscale.hostname must be set when tailscale.enable is true";
      }
    ];

    systemd.services.seaweedfs = {
      description = "SeaweedFS - distributed object storage";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p ${cfg.master.dataDir}
        mkdir -p ${cfg.volume.dataDir}
        mkdir -p ${cfg.configDir}
        ${optionalString cfg.filer.enable "mkdir -p ${cfg.filer.dataDir}"}
        chown -R seaweedfs:seaweedfs ${cfg.master.dataDir} ${cfg.volume.dataDir} ${cfg.configDir} ${optionalString cfg.filer.enable cfg.filer.dataDir}
      '';

      serviceConfig = {
        Type = "simple";
        User = "seaweedfs";
        Group = "seaweedfs";
        Restart = "on-failure";
        RestartSec = 5;

        ExecStart = ''
          ${cfg.package}/bin/weed server \
            -ip=${cfg.ip} \
            ${optionalString cfg.tailscale.enable "-ip.bind=${cfg.tailscale.hostname}"} \
            ${optionalString cfg.filer.enable "-filer"} \
            ${optionalString cfg.s3.enable "-s3"} \
            -master.mdir=${cfg.master.dataDir} \
            -dir=${cfg.volume.dataDir} \
            -volume.max=${toString cfg.volume.maxSize} \
            -master.volumeSizeLimitMB=${toString cfg.volume.maxVolumeSizeMb} \
            ${optionalString cfg.s3.enable "-s3.port=${toString cfg.s3.port}"} \
            ${optionalString cfg.filer.enable "-filer.port=${toString cfg.filer.port}"} \
            ${optionalString (cfg.master.metricsAddress != null) "-metrics.address=${cfg.master.metricsAddress}"} \
            -metricsPort=9324
        '';

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/rpool/unenc/apps/nixos" ];
      };
    };

    users.users.seaweedfs = {
      isSystemUser = true;
      group = "seaweedfs";
      home = "/var/lib/seaweedfs";
      createHome = true;
    };

    users.groups.seaweedfs = { };
  };
}
