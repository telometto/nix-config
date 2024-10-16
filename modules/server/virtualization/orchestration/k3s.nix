# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  virtualisation = {
    # k3s-related; more info at https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cluster/k3s/docs/examples/STORAGE.md
    containerd = {
      enable = true;

      settings =
        let
          fullCNIPlugins = pkgs.buildEnv {
            name = "full-cni";
            paths = with pkgs; [
              cni-plugins
              cni-plugin-flannel
            ];
          };
        in
        {
          plugins."io.containerd.grpc.v1.cri" = {
            cni = {
              bin_dir = "${fullCNIPlugins}/bin";
              conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d/";
            };

            containerd = {
              snapshotter = "zfs";
            };
          };
        };
    };
  };

  services = {
    rpcbind.enable = true; # Required for NFS on k3s

    k3s = {
      enable = true;
      role = "server";
      extraFlags = toString [ "--container-runtime-endpoint unix:///run/containerd/containerd.sock" ];
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
}
