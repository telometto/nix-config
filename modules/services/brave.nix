{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.brave;
  isHost = cfg.networkMode == "host";

  hasCredentials = cfg.customUserFile != null && cfg.passwordFile != null;
  credentialsEnvFile = "/run/brave/credentials.env";

  environment = {
    TZ = cfg.timeZone;
    TITLE = cfg.title;
  }
  // lib.optionalAttrs (cfg.driNode != null) { DRINODE = cfg.driNode; }
  // lib.optionalAttrs isHost {
    CUSTOM_PORT = toString cfg.httpPort;
    CUSTOM_HTTPS_PORT = toString cfg.httpsPort;
  };

  ports = lib.optionals (!isHost) [
    "${toString cfg.httpPort}:3000"
    "${toString cfg.httpsPort}:3001"
  ];

  extraOptions = [
    "--shm-size=4g"
  ]
  ++ lib.optional cfg.enableDri "--device=/dev/dri"
  ++ lib.optional isHost "--network=host";

  preStartScript = pkgs.writeShellScript "brave-credentials" ''
    set -euo pipefail
    umask 0077
    : > ${credentialsEnvFile}
    printf 'CUSTOM_USER=%s\n' "$(cat "${cfg.customUserFile}")" >> ${credentialsEnvFile}
    printf 'PASSWORD=%s\n' "$(cat "${cfg.passwordFile}")" >> ${credentialsEnvFile}
    chmod 0400 ${credentialsEnvFile}
  '';
in
{
  options.sys.services.brave = {
    enable = lib.mkEnableOption "Brave";

    image = lib.mkOption {
      type = lib.types.str;
      default = "linuxserver/brave:latest";
      description = "Container image to run.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/brave";
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
      default = "Brave";
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

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
    ];

    systemd.services.podman-brave = lib.mkIf hasCredentials {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
      serviceConfig = {
        RuntimeDirectory = "brave";
        RuntimeDirectoryMode = "0700";
        ExecStartPre = [ "+${preStartScript}" ];
      };
    };

    virtualisation.oci-containers.containers.brave = {
      inherit (cfg) image;
      autoStart = true;
      inherit environment ports extraOptions;
      volumes = [ "${cfg.dataDir}:/config" ];
      environmentFiles = lib.optionals hasCredentials [ credentialsEnvFile ];
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
        message = "sys.services.brave: customUserFile and passwordFile must both be set or both be null";
      }
    ];
  };
}
