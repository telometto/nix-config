{ lib, config, pkgs, ... }:
let
  cfg = config.sys.services.flaresolverr;
in
{
  options.sys.services.flaresolverr = {
    enable = lib.mkEnableOption "FlareSolverr";

    package = lib.mkPackageOption pkgs "flaresolverr" { };

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

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    services.flaresolverr = {
      enable = true;
      inherit (cfg) package port openFirewall;
    };

    systemd.services.flaresolverr.environment = {
      HOST = cfg.bind;
      LOG_LEVEL = cfg.logLevel;
    };
  };
}
