# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  networking = {
    firewall = rec {
      allowedTCPPortRanges = [{ from = 1714; to = 1764; }];
      allowedUDPPortRanges = allowedTCPPortRanges;

      allowedTCPPorts = [
        # 6443 # k3s; required so that pods can reach the API server (running on port 6443 by default)
        # 2379 # k3s; etcd clients: required if using a "High Availability Embedded etcd" configuration
        # 2380 # k3s; etcd peers: required if using a "High Availability Embedded etcd" configuration
      ];

      allowedUDPPorts = [
        # 8472 # k3s, flannel: required if using multi-node for inter-node networking
      ];
    };

    #proxy = {
    #  default = "http://user:password@proxy:port/";
    #  noProxy = "127.0.0.1,localhost,internal.domain";
    #};
  };
}
