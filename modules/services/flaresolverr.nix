{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.flaresolverr;
in
{
  options.sys.services.flaresolverr = {
    enable = lib.mkEnableOption "FlareSolverr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8191;
      description = "Port where FlareSolverr listens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    services.flaresolverr = {
      enable = true;
      inherit (cfg) port openFirewall;
    };
    systemd.services.flaresolverr.environment.HOST = "127.0.0.1";

    assertions = [
      {
        assertion = !cfg.openFirewall;
        message = "FlareSolverr is an unauthenticated local helper; remote publication requires a separately authenticated service.";
      }
    ];
  };
}
