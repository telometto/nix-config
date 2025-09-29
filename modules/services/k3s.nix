{ lib, config, ... }:
let cfg = config.telometto.services.k3s or { };
in {
  options.telometto.services.k3s = {
    enable = lib.mkEnableOption "k3s Kubernetes";
    role = lib.mkOption {
      type = lib.types.str;
      default = "server";
    };
    gracefulNodeShutdown = lib.mkOption {
      type = lib.types.attrs;
      default = {
        enable = false;
        shutdownGracePeriod = "1m30s";
        shutdownGracePeriodCriticalPods = "1m";
      };
    };
    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "--snapshotter native" ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.rpcbind.enable =
      lib.mkDefault true; # legacy requirement for some NFS-on-k3s setups
    services.k3s = {
      enable = lib.mkDefault true;
      inherit (cfg) role gracefulNodeShutdown extraFlags;
    };
  };
}
