{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.firefox;
  isHost = cfg.networkMode == "host";

  hasCredentials = cfg.customUserFile != null && cfg.passwordFile != null;
  credentialsEnvFile = "/run/firefox/credentials.env";

  environments = {
    TZ = cfg.timeZone;
    TITLE = cfg.title;
  }
  // lib.optionalAttrs (cfg.driNode != null) { DRINODE = cfg.driNode; }
  // lib.optionalAttrs cfg.fileTransfer.enable {
    # Keep the existing LinuxServer profile identity separate from the
    # VM-side ownership of the shared transfer directory. Changing PUID to
    # the VM user's UID also changes the identity that opens /config.
    PUID = toString cfg.fileTransfer.containerUid;
    PGID = toString cfg.fileTransfer.sharedGid;
    FILE_MANAGER_PATH = cfg.fileTransfer.containerPath;
    SELKIES_FILE_TRANSFERS = "upload,download";
  }
  // lib.optionalAttrs isHost {
    CUSTOM_PORT = toString cfg.httpPort;
    CUSTOM_HTTPS_PORT = toString cfg.httpsPort;
  };

  publishPorts = lib.optionals (!isHost) [
    "${toString cfg.httpPort}:3000"
    "${toString cfg.httpsPort}:3001"
  ];

  preStartScript = pkgs.writeShellScript "firefox-credentials" ''
    set -euo pipefail
    umask 0077
    : > ${credentialsEnvFile}
    printf 'CUSTOM_USER=%s\n' "$(cat "${cfg.customUserFile}")" >> ${credentialsEnvFile}
    printf 'PASSWORD=%s\n' "$(cat "${cfg.passwordFile}")" >> ${credentialsEnvFile}
    chmod 0400 ${credentialsEnvFile}
  '';
in
{
  options.sys.services.firefox = {
    enable = lib.mkEnableOption "Firefox";

    image = lib.mkOption {
      type = lib.types.str;
      default = "linuxserver/firefox:latest";
      description = "Container image to run.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/firefox";
      description = "Container /config volume path on the VM.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "HTTP port exposed by the container.";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "HTTPS port exposed by the container.";
    };

    # Host mode is recommended for single-purpose MicroVMs:
    # - Bridge mode fails because systemd-networkd manages Podman veth
    #   interfaces (microvm-nix#203); fixable via Unmanaged = true.
    # - Host mode is safe here: VM-to-host isolation is enforced by the
    #   hypervisor, not by container networking. Both modes are equivalent
    #   for preventing escape to the physical network.
    networkMode = lib.mkOption {
      type = lib.types.enum [
        "bridge"
        "host"
      ];
      default = "host";
      description = "Container network mode.";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
    };

    title = lib.mkOption {
      type = lib.types.str;
      default = "Firefox";
    };

    customUserFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to a file containing the basic-auth username for the web UI.";
    };

    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to a file containing the basic-auth password for the web UI.";
    };

    driNode = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional DRM render node path inside the container.";
    };

    enableDri = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose /dev/dri to the container.";
    };

    fileTransfer = {
      enable = lib.mkEnableOption "Firefox file transfers";

      hostPath = lib.mkOption {
        type = lib.types.str;
        default = "/home/admin/Downloads";
        description = "Writable VM path to expose to the browser file manager.";
      };

      containerPath = lib.mkOption {
        type = lib.types.str;
        default = "/downloads";
        description = "Path inside the Firefox container used for uploads and downloads.";
      };

      hostUid = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1000;
        description = "Numeric owner UID for the VM-side file-transfer directory.";
      };

      sharedGid = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1000;
        description = "Numeric group GID shared by the VM-side directory and container.";
      };

      containerUid = lib.mkOption {
        type = lib.types.ints.positive;
        default = 911;
        description = "PUID for the LinuxServer container's existing /config profile identity.";
      };
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
    ]
    ++ lib.optional cfg.fileTransfer.enable "d ${cfg.fileTransfer.hostPath} 2770 ${toString cfg.fileTransfer.hostUid} ${toString cfg.fileTransfer.sharedGid} -";

    systemd.services.firefox = lib.mkIf hasCredentials {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
      serviceConfig = {
        RuntimeDirectory = "firefox";
        RuntimeDirectoryMode = "0700";
        ExecStartPre = [ "+${preStartScript}" ];
      };
    };

    virtualisation.quadlet.containers.firefox = {
      autoStart = true;
      containerConfig = {
        inherit (cfg) image;
        inherit environments publishPorts;
        shmSize = "4g";
        volumes = [
          "${cfg.dataDir}:/config"
        ]
        ++ lib.optional cfg.fileTransfer.enable "${cfg.fileTransfer.hostPath}:${cfg.fileTransfer.containerPath}";
        networks = lib.optionals isHost [ "host" ];
        devices = lib.optionals cfg.enableDri [ "/dev/dri" ];
        environmentFiles = lib.optionals hasCredentials [ credentialsEnvFile ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        cfg.httpPort
        cfg.httpsPort
      ];
    };

    assertions = [
      {
        assertion = (cfg.customUserFile == null) == (cfg.passwordFile == null);
        message = "sys.services.firefox: customUserFile and passwordFile must both be set or both be null";
      }
      {
        assertion = !cfg.fileTransfer.enable || lib.hasPrefix "/" cfg.fileTransfer.hostPath;
        message = "sys.services.firefox.fileTransfer.hostPath must be an absolute path";
      }
      {
        assertion = !cfg.fileTransfer.enable || lib.hasPrefix "/" cfg.fileTransfer.containerPath;
        message = "sys.services.firefox.fileTransfer.containerPath must be an absolute path";
      }
    ];
  };
}
