{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.metube;
  uid = toString cfg.uid;
  gid = toString cfg.gid;
  prepareDirectories = pkgs.writeShellScript "prepare-metube-directories" ''
    set -eu
    ${lib.getExe' pkgs.coreutils "install"} -d -m 0775 -o ${uid} -g ${gid} ${lib.escapeShellArg cfg.downloadDir}
    ${lib.getExe' pkgs.coreutils "install"} -d -m 0775 -o ${uid} -g ${gid} ${lib.escapeShellArg "${cfg.downloadDir}/.tmp"}
    ${lib.getExe' pkgs.coreutils "install"} -d -m 0750 -o ${uid} -g ${gid} ${lib.escapeShellArg cfg.stateDir}
  '';
in
{
  options.sys.services.metube = {
    enable = lib.mkEnableOption "MeTube";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/alexta69/metube:2026.07.27";
      description = "MeTube OCI image to run.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "TCP port on which MeTube listens.";
    };

    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = "/data/downloads/metube";
      description = "Persistent directory exposed to MeTube as /downloads.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/metube";
      description = "Persistent directory for MeTube queue and subscription state.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Numeric UID used by MeTube inside the container.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Numeric GID used by MeTube inside the container.";
    };

    umask = lib.mkOption {
      type = lib.types.str;
      default = "002";
      description = "Umask applied to files created by MeTube.";
    };

    maxConcurrentDownloads = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Maximum number of simultaneous downloads.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the MeTube port in the guest firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.downloadDir;
        message = "sys.services.metube.downloadDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.stateDir;
        message = "sys.services.metube.stateDir must be an absolute path.";
      }
      {
        assertion = cfg.downloadDir != cfg.stateDir;
        message = "sys.services.metube.downloadDir and stateDir must be different paths.";
      }
      {
        assertion = cfg.uid >= 0 && cfg.gid >= 0;
        message = "sys.services.metube.uid and gid must be non-negative integers.";
      }
      {
        assertion = cfg.maxConcurrentDownloads > 0;
        message = "sys.services.metube.maxConcurrentDownloads must be positive.";
      }
    ];

    virtualisation.quadlet.containers.metube = {
      autoStart = true;

      containerConfig = {
        inherit (cfg) image;
        networks = [ "host" ];
        noNewPrivileges = true;
        volumes = [
          "${cfg.downloadDir}:/downloads"
          "${cfg.stateDir}:/config"
        ];
        environments = {
          PUID = uid;
          PGID = gid;
          UMASK = cfg.umask;
          CHOWN_DIRS = "false";
          HOST = "0.0.0.0";
          PORT = toString cfg.port;
          DOWNLOAD_DIR = "/downloads";
          STATE_DIR = "/config";
          TEMP_DIR = "/downloads/.tmp";
          MAX_CONCURRENT_DOWNLOADS = toString cfg.maxConcurrentDownloads;
          ALLOW_PRIVATE_ADDRESSES = "false";
          ALLOW_YTDL_OPTIONS_OVERRIDES = "false";
          DOWNLOAD_DIRS_INDEXABLE = "false";
        };
      };

      unitConfig = {
        Wants = [ "network-online.target" ];
        After = [ "network-online.target" ];
        RequiresMountsFor = [
          cfg.downloadDir
          cfg.stateDir
        ];
      };

      serviceConfig = {
        ExecStartPre = [ "${prepareDirectories}" ];
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "300s";
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
