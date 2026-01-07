{ lib, config, ... }:
let
  cfg = config.sys.services.k3s or { };
in
{
  options.sys.services.k3s = {
    enable = lib.mkEnableOption "k3s Kubernetes";
    role = lib.mkOption {
      type = lib.types.str;
      default = "server";
    };

    gracefulNodeShutdown = lib.mkOption {
      type = lib.types.attrs;
      default = {
        enable = lib.mkDefault false;
        shutdownGracePeriod = lib.mkDefault "1m30s";
        shutdownGracePeriodCriticalPods = lib.mkDefault "1m";
      };
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "--snapshotter native" ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.rpcbind.enable = lib.mkDefault true;

    services.k3s = {
      enable = lib.mkDefault true;
      inherit (cfg) role gracefulNodeShutdown extraFlags;
    };
  };
}
