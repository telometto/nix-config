{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.securityLogArchive;
  package = pkgs.callPackage ../../packages/security-log-archive { };
  reader = "security-log-reader";
  uploader = "security-log-uploader";
  group = "security-log-archive";
  metricsDir = "/var/lib/prometheus-node-exporter/security-log-archive";
  secretPath = name: "/run/secrets/security-log-archive/${name}";
  sshArgs =
    identity:
    [
      "-F"
      "/dev/null"
      "-T"
      "-o"
      "BatchMode=yes"
      "-o"
      "IdentitiesOnly=yes"
      "-o"
      "StrictHostKeyChecking=yes"
      "-o"
      "ConnectTimeout=10"
      "-o"
      "ServerAliveInterval=10"
      "-o"
      "ServerAliveCountMax=2"
      "-o"
      "UserKnownHostsFile=${cfg.knownHostsFile}"
      "-p"
      (toString cfg.sshPort)
    ]
    ++ lib.optionals (identity != null) [
      "-i"
      identity
    ];
  transport = pkgs.writeShellScript "security-log-archive-transport" ''
    exec ${pkgs.openssh}/bin/ssh ${lib.escapeShellArgs (sshArgs null)} \
      -i "$CREDENTIALS_DIRECTORY/upload-ssh" ${lib.escapeShellArg cfg.sshTarget} \
      ${lib.escapeShellArg "rclone serve restic --stdio --append-only ${cfg.repositoryName}"}
  '';
  base = {
    host = cfg.sourceHost;
    repository_id = cfg.repositoryId;
    repository = "rclone:${cfg.repositoryName}";
    admin_repository = "sftp:${cfg.sshTarget}:./${cfg.repositoryName}";
    state_dir = cfg.stateDir;
    staging_dir = cfg.stagingDir;
    buffer_bytes = cfg.bufferBytes;
    min_free_bytes = cfg.minFreeBytes;
    seal_seconds = 30;
    metrics_file = "${metricsDir}/archive.prom";
    upload_options = {
      "rclone.program" = toString transport;
      "rclone.args" = "serve restic --stdio --append-only";
    };
    provenance = {
      configuration_revision = config.system.configurationRevision;
      nixos_version = config.system.nixos.version;
      restic_version = pkgs.restic.version;
      lock_sha256 = builtins.hashFile "sha256" ../../flake.lock;
    };
  };
  uploadConfig = pkgs.writeText "security-log-archive.json" (builtins.toJSON base);
  adminConfig = pkgs.writeText "security-log-archive-admin.json" (
    builtins.toJSON (
      base
      // {
        credentials = {
          password = cfg.admin.passwordFile;
        };
        admin_options."sftp.command" = lib.escapeShellArgs (
          [ "${pkgs.openssh}/bin/ssh" ]
          ++ sshArgs cfg.admin.identityFile
          ++ [
            "-s"
            cfg.sshTarget
            "sftp"
          ]
        );
      }
    )
  );
  hardening = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    RestrictNamespaces = true;
    LockPersonality = true;
    UMask = "0007";
    MemoryMax = "256M";
    TasksMax = 64;
    CapabilityBoundingSet = "";
  };
  absolute = value: lib.hasPrefix "/" value && !(lib.hasInfix "/../" value);
in
{
  options.sys.services.securityLogArchive = {
    enable = lib.mkEnableOption "durable off-host security-log archival";
    sourceHost = lib.mkOption {
      type = lib.types.str;
      default = "blizzard";
      description = "Host whose selected journals are archived";
    };
    sshTarget = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9._-]+@[A-Za-z0-9.-]+";
      default = "zh6100@zh6100.rsync.net";
      description = "Pinned rsync.net account and server";
    };
    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 22;
    };
    repositoryName = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9_-]+";
      default = "blizzard-security-logs";
      description = "Dedicated repository, relative to the rsync.net account";
    };
    repositoryId = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[0-9a-f]{64}");
      default = null;
      description = "Repository ID recorded during independent provisioning";
    };
    knownHostsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/ssh/security-log-archive-known-hosts";
      description = "Independently verified SSH host-key file";
    };
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/security-log-archive";
    };
    stagingDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/security-log-archive-upload";
    };
    bufferBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 20 * 1024 * 1024 * 1024;
      description = "Spool budget including a reservation for upload staging and metadata";
    };
    minFreeBytes = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 5 * 1024 * 1024 * 1024;
      description = "Filesystem free-space floor; collection pauses before crossing it";
    };
    identityFile = lib.mkOption {
      type = lib.types.str;
      default = secretPath "upload-ssh";
    };
    passwordFile = lib.mkOption {
      type = lib.types.str;
      default = secretPath "password";
    };
    heartbeatUrlFile = lib.mkOption {
      type = lib.types.str;
      default = secretPath "heartbeat-url";
    };
    admin = {
      enable = lib.mkEnableOption "manual security-log archive recovery and retention commands";
      identityFile = lib.mkOption {
        type = lib.types.str;
        default = secretPath "admin-ssh";
      };
      passwordFile = lib.mkOption {
        type = lib.types.str;
        default = secretPath "password";
      };
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = package;
      readOnly = true;
      description = "Archive CLI built from this repository";
    };
    clientConfigFile = lib.mkOption {
      type = lib.types.path;
      default = uploadConfig;
      readOnly = true;
      description = "Public uploader configuration; credentials are loaded at runtime";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable || cfg.admin.enable) {
      assertions = [
        {
          assertion = cfg.repositoryId != null;
          message = "securityLogArchive requires the independently provisioned repositoryId";
        }
        {
          assertion = lib.all absolute [
            cfg.stateDir
            cfg.stagingDir
            cfg.knownHostsFile
            cfg.identityFile
            cfg.passwordFile
            cfg.heartbeatUrlFile
            cfg.admin.identityFile
            cfg.admin.passwordFile
          ];
          message = "securityLogArchive state and credential paths must be absolute";
        }
        {
          assertion = cfg.stateDir != cfg.stagingDir;
          message = "securityLogArchive staging and spool directories must differ";
        }
        {
          assertion = cfg.bufferBytes >= 256 * 1024 * 1024;
          message = "securityLogArchive needs at least 256 MiB for bounded staging and metadata";
        }
        {
          assertion = cfg.admin.identityFile != cfg.identityFile;
          message = "securityLogArchive requires distinct upload and administration SSH credentials";
        }
        {
          assertion = !(cfg.enable && cfg.admin.enable);
          message = "securityLogArchive upload and administrative credentials must live on separate hosts";
        }
      ];
    })
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.sourceHost == config.networking.hostName;
          message = "securityLogArchive sourceHost must match the collecting host";
        }
      ];
      users = {
        groups.${group} = { };
        users = {
          ${reader} = {
            isSystemUser = true;
            inherit group;
            extraGroups = [ "systemd-journal" ];
          };
          ${uploader} = {
            isSystemUser = true;
            inherit group;
          };
        };
      };
      services.journald.storage = "persistent";
      services.prometheus.exporters.node = {
        enabledCollectors = [ "textfile" ];
        extraFlags = [ "--collector.textfile.directory=${metricsDir}" ];
      };
      systemd = {
        tmpfiles.rules = [
          "d ${cfg.stateDir} 2770 ${reader} ${group} -"
          "d ${cfg.stateDir}/ready 2770 ${reader} ${group} -"
          "d ${cfg.stagingDir} 0700 ${uploader} ${group} -"
          "d ${metricsDir} 2775 ${reader} ${group} -"
        ];
        services = {
          security-log-archive-collector = {
            description = "Seal allowlisted security journal records into a durable spool";
            wantedBy = [ "multi-user.target" ];
            after = [
              "systemd-journal-flush.service"
              "systemd-tmpfiles-setup.service"
            ];
            serviceConfig = hardening // {
              User = reader;
              Group = group;
              SupplementaryGroups = [ "systemd-journal" ];
              ExecStart = "${package}/bin/security-log-archive --config ${uploadConfig} collect";
              Restart = "on-failure";
              RestartSec = "10s";
              TimeoutStopSec = "10s";
              PrivateNetwork = true;
              RestrictAddressFamilies = [ "AF_UNIX" ];
              ReadWritePaths = [
                cfg.stateDir
                metricsDir
              ];
            };
          };
          security-log-archive-upload = {
            description = "Commit sealed security records to append-only rsync.net storage";
            wants = [ "network-online.target" ];
            requires = [ "security-log-archive-collector.service" ];
            after = [
              "network-online.target"
              "security-log-archive-collector.service"
            ];
            serviceConfig = hardening // {
              Type = "oneshot";
              User = uploader;
              Group = group;
              ExecStart = "${package}/bin/security-log-archive --config ${uploadConfig} upload";
              TimeoutStartSec = "60s";
              ReadWritePaths = [
                cfg.stateDir
                cfg.stagingDir
                metricsDir
              ];
              RestrictAddressFamilies = [
                "AF_UNIX"
                "AF_INET"
                "AF_INET6"
              ];
              LoadCredential = [
                "upload-ssh:${cfg.identityFile}"
                "password:${cfg.passwordFile}"
                "heartbeat-url:${cfg.heartbeatUrlFile}"
              ];
            };
          };
        };
        timers.security-log-archive-upload = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* *:0/2:00 UTC";
            Persistent = true;
            AccuracySec = "1s";
            RandomizedDelaySec = 0;
          };
        };
      };
    })
    (lib.mkIf cfg.admin.enable {
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "security-log-archive-admin" ''
          exec ${package}/bin/security-log-archive --config ${adminConfig} "$@"
        '')
      ];
    })
  ];
}
