{ lib, config, ... }:
let
  cfg = config.sys.services.brave;
  isHost = cfg.networkMode == "host";

  environment = {
    TZ = cfg.timeZone;
    TITLE = cfg.title;
  }
  // lib.optionalAttrs (cfg.customUser != null) { CUSTOM_USER = cfg.customUser; }
  // lib.optionalAttrs (cfg.password != null) { PASSWORD = cfg.password; }
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

    customUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional basic auth username for the web UI.";
    };

    password = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional basic auth password for the web UI.";
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

    virtualisation.oci-containers.containers.brave = {
      inherit (cfg) image;
      autoStart = true;
      inherit environment ports extraOptions;
      volumes = [ "${cfg.dataDir}:/config" ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        cfg.httpPort
        cfg.httpsPort
      ];
    };
  };
}
