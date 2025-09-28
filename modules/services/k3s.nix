{ lib, config, ... }:
let cfg = config.telometto.services.k3s or { };
in {
  options.telometto.services.k3s.enable = lib.mkEnableOption "k3s Kubernetes";
  options.telometto.services.k3s.role = lib.mkOption {
    type = lib.types.str;
    default = "server";
  };
  options.telometto.services.k3s.gracefulNodeShutdown = lib.mkOption {
    type = lib.types.attrs;
    default = {
      enable = false;
      shutdownGracePeriod = "1m30s";
      shutdownGracePeriodCriticalPods = "1m";
    };
  };
  options.telometto.services.k3s.extraFlags = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ "--snapshotter native" ];
  };

  config = lib.mkIf cfg.enable {
    services.rpcbind.enable =
      lib.mkDefault true; # legacy requirement for some NFS-on-k3s setups
    services.k3s = {
      enable = lib.mkDefault true;
      role = cfg.role;
      gracefulNodeShutdown = cfg.gracefulNodeShutdown;
      extraFlags = cfg.extraFlags;
    };
  };
}
