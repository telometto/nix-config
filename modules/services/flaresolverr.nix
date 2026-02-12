{ lib, config, pkgs, ... }:
let
  cfg = config.sys.services.flaresolverr;
  port = toString cfg.port;
in
{
  options.sys.services.flaresolverr = {
    enable = lib.mkEnableOption "FlareSolverr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8191;
      description = "Port where FlareSolverr listens.";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Bind address for FlareSolverr.";
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "info";
      description = "Log level for FlareSolverr.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "flaresolverr";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "flaresolverr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };

    systemd.services.flaresolverr = {
      description = "FlareSolverr";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pkgs.flaresolverr}/bin/flaresolverr";
        Restart = "on-failure";
        Environment = [
          "HOST=${cfg.bind}"
          "PORT=${port}"
          "LOG_LEVEL=${cfg.logLevel}"
        ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
