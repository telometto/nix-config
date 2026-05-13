{ lib, config, ... }:
let
  cfg = config.sys.services.k3s or { };

  ciliumFlags = [
    "--disable=servicelb"
    "--disable-kube-proxy"
    "--flannel-backend=none"
    "--disable-network-policy"
  ];
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

    # When true, appends --disable=servicelb / --disable-kube-proxy /
    # --flannel-backend=none / --disable-network-policy so Cilium can take
    # over LoadBalancer handling, CNI, and kube-proxy replacement.
    # Keep false (the default) if you are not deploying Cilium; without a CNI
    # the node will stay NotReady indefinitely.
    ciliumCni = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Cilium-compatible k3s flags (disables flannel, kube-proxy, and built-in network policy).";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--snapshotter=native"
        "--disable=traefik"
        "--kubelet-arg=read-only-port=10255"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.rpcbind.enable = lib.mkDefault true;

    services.k3s = {
      enable = lib.mkDefault true;
      inherit (cfg) role gracefulNodeShutdown;
      extraFlags = cfg.extraFlags ++ lib.optionals cfg.ciliumCni ciliumFlags;
    };
  };
}
