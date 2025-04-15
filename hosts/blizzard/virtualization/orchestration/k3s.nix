# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services = {
    rpcbind.enable = lib.mkOptionDefault true; # Required for NFS on k3s

    k3s = {
      enable = true;

      role = "server";

      gracefulNodeShutdown = {
        enable = false;

        shutdownGracePeriod = "1m30s";
        shutdownGracePeriodCriticalPods = "1m";
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
      # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
      # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
    ];

    allowedUDPPorts = [
      # 8472 # k3s, flannel: required if using multi-node for inter-node networking
    ];
  };

  environment.systemPackages = with pkgs; [
    (wrapHelm kubernetes-helm {
      plugins = with pkgs.kubernetes-helmPlugins; [
        helm-secrets
        helm-diff
        helm-s3
        helm-git
      ];
    })
  ];
}
