{ lib, config, ... }:
let
  cfg = config.sys.services.firefox;
  envBase = {
    TZ = cfg.timeZone;
    TITLE = cfg.title;
  };
  envUser = lib.optionalAttrs (cfg.customUser != null) {
    CUSTOM_USER = cfg.customUser;
  };
  envPassword = lib.optionalAttrs (cfg.password != null) {
    PASSWORD = cfg.password;
  };
  envDri = lib.optionalAttrs (cfg.driNode != null) {
    DRINODE = cfg.driNode;
  };
  environment = envBase // envUser // envPassword // envDri;
  ports = [
    "${toString cfg.httpPort}:3000"
    "${toString cfg.httpsPort}:3001"
  ];
  volumes = [
    "${cfg.dataDir}:/config"
  ];
  extraOptions = [ "--shm-size=4g" ] ++ lib.optional cfg.enableDri "--device=/dev/dri";
in
{
  options.sys.services.firefox = {
    enable = lib.mkEnableOption "Firefox (LinuxServer Kasm)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "linuxserver/firefox:kasm";
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

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
    };

    title = lib.mkOption {
      type = lib.types.str;
      default = "Firefox";
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

    virtualisation.oci-containers.containers.firefox = {
      inherit (cfg) image;
      autoStart = true;
      inherit
        environment
        ports
        volumes
        extraOptions
        ;
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        cfg.httpPort
        cfg.httpsPort
      ];
    };
  };
}
