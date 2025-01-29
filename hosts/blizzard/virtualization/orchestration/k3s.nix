# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  # Disabled for testing (not using ZFS for now)
  virtualisation = {
    # k3s-related; more info at https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cluster/k3s/docs/examples/STORAGE.md
    containerd = {
      enable = true;

      settings = let
        fullCNIPlugins = pkgs.buildEnv {
          name = "full-cni";
          paths = with pkgs; [ cni-plugins cni-plugin-flannel ];
        };
      in {
        plugins."io.containerd.grpc.v1.cri" = {
          cni = {
            bin_dir = "${fullCNIPlugins}/bin";
            conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d/";
          };

          # config.toml does not get declaratively edited; needs to be done manually
          # containerd = {
          #   snapshotter = "zfs";
          # };
        };
      };
    };
  };

  services = {
    rpcbind.enable = lib.mkOptionDefault true; # Required for NFS on k3s

    k3s = {
      enable = true;

      role = "server";
      gracefulNodeShutdown = { enable = true; };
      ## Disabled for testing (not using ZFS for now)
      extraFlags = toString [
        "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
        # "--disable=servicelb"
        # "--docker"
        "--snapshotter=native"
      ];
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
    containerd # Disabled for testing (not using ZFS for now)
    k3s

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
