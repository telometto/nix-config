# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  virtualisation = {
    docker = {
      daemon.settings = {
        data-root = "/add/path/here";
        userland-proxy = false;
        experimental = true;
        metrics-addr = "0.0.0.0:9323";
        ipv6 = true;
        #fixed-cidr-v6 = "fd00::/80";
      };

      storageDriver = "zfs";
    };
  };
}
