{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.sys.services.seaweedfs;
  advertisedIp =
    if cfg.tailscale.enable && cfg.tailscale.hostname != null then cfg.tailscale.hostname else cfg.ip;
in
{
  options.sys.services.seaweedfs = {
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

      port = mkOption {
        type = types.port;
        default = 9333;
        description = "Master server port (internal coordination)";
      };

      metricsAddress = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Prometheus gateway address for metrics";
      };
    };

    metrics = {
      enable = mkEnableOption "metrics endpoint" // {
        default = true;
      };

      port = mkOption {
        type = types.port;
        default = 9324;
        description = "Prometheus metrics port";
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

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Volume server HTTP port (data storage and retrieval)";
      };

      grpcPort = mkOption {
        type = types.port;
        default = 18080;
        description = "Volume server gRPC port (internal communication)";
      };
    };

    ip = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IP address to bind to";
    };

    bindAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Bind address for Weed services (ip.bind)";
    };

    s3 = {
      enable = mkEnableOption "S3 API support" // {
        default = true;
      };

      port = mkOption {
        type = types.port;
        default = 8333;
        description = "S3 API server port (S3-compatible access)";
      };

      auth = {
        enable = mkEnableOption "S3 authentication";

        accessKeyFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Path to a file containing the S3 access key";
        };

        secretAccessKeyFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Path to a file containing the S3 secret access key";
        };
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall for S3 port";
    };

    filer = {
      enable = mkEnableOption "Filer service" // {
        default = true;
      };

      port = mkOption {
        type = types.port;
        default = 8888;
        description = "Filer server port (directory and file operations)";
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
      {
        assertion =
          !cfg.s3.auth.enable
          || (cfg.s3.auth.accessKeyFile != null && cfg.s3.auth.secretAccessKeyFile != null);
        message = "services.seaweedfs.s3.auth.accessKeyFile and secretAccessKeyFile must be set when s3.auth.enable is true";
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
        ${optionalString cfg.s3.auth.enable ''
            accessKeyFile="$CREDENTIALS_DIRECTORY/seaweedfs-s3-access-key"
            secretKeyFile="$CREDENTIALS_DIRECTORY/seaweedfs-s3-secret-key"

            if [ ! -s "$accessKeyFile" ] || [ ! -s "$secretKeyFile" ]; then
              echo "SeaweedFS S3 credentials missing" >&2
              exit 1
            fi

            cat > ${cfg.configDir}/s3.config.json << EOF
          {
            "identities": [
              {
                "name": "admin",
                "credentials": [
                  {
                    "accessKey": "$(cat "$accessKeyFile")",
                    "secretKey": "$(cat "$secretKeyFile")"
                  }
                ],
                "actions": [
                  "Admin",
                  "Read",
                  "Write",
                  "List",
                  "Tagging"
                ]
              }
            ]
          }
          EOF
        ''}
        chown -R seaweedfs:seaweedfs ${cfg.master.dataDir} ${cfg.volume.dataDir} ${cfg.configDir} ${optionalString cfg.filer.enable cfg.filer.dataDir}
      '';

      serviceConfig = {
        Type = "simple";
        User = "seaweedfs";
        Group = "seaweedfs";
        Restart = "on-failure";
        RestartSec = 5;

        LoadCredential = lib.optionals cfg.s3.auth.enable [
          "seaweedfs-s3-access-key:${cfg.s3.auth.accessKeyFile}"
          "seaweedfs-s3-secret-key:${cfg.s3.auth.secretAccessKeyFile}"
        ];

        ExecStart = ''
          ${cfg.package}/bin/weed server \
            -ip=${advertisedIp} \
            -ip.bind=${cfg.bindAddress} \
            ${optionalString cfg.filer.enable "-filer"} \
            ${optionalString cfg.s3.enable "-s3"} \
            -master.port=${toString cfg.master.port} \
            -master.dir=${cfg.master.dataDir} \
            -dir=${cfg.volume.dataDir} \
            -volume.max=${toString cfg.volume.maxSize} \
            -volume.port=${toString cfg.volume.port} \
            -volume.port.grpc=${toString cfg.volume.grpcPort} \
            -master.volumeSizeLimitMB=${toString cfg.volume.maxVolumeSizeMb} \
            ${optionalString cfg.s3.enable "-s3.port=${toString cfg.s3.port}"} \
            ${
              optionalString (cfg.s3.enable && cfg.s3.auth.enable) "-s3.config=${cfg.configDir}/s3.config.json"
            } \
            ${optionalString cfg.filer.enable "-filer.port=${toString cfg.filer.port}"} \
            ${
              optionalString (cfg.master.metricsAddress != null) "-metrics.address=${cfg.master.metricsAddress}"
            } \
            ${optionalString cfg.metrics.enable "-metricsPort=${toString cfg.metrics.port}"}
        '';

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          cfg.master.dataDir
          cfg.volume.dataDir
          cfg.configDir
        ]
        ++ lib.optional cfg.filer.enable cfg.filer.dataDir;
      };
    };

    users.users.seaweedfs = {
      isSystemUser = true;
      group = "seaweedfs";
      home = "/var/lib/seaweedfs";
      createHome = true;
    };

    users.groups.seaweedfs = { };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = lib.optional cfg.s3.enable cfg.s3.port;
    };
  };
}
