{ config, pkgs, lib, ... }:
let
  PRIVATEKEYFILE = config.sops.secrets."general/wireguardKeyFile".path; # config.sops.secrets.wireguardKeyFile.path;
  ADDRESS = [ "10.2.0.2/32" ];
  DNS = [ "10.2.0.1" ];
  PUBLICKEY = "/0vWJERpbXUXRThD8pnWYfZ3HrEaRTp5ZBcE2YQw7TI=";
  ALLOWEDIPS = [ "0.0.0.0/0" ];
  ENDPOINT = "95.173.205.129:51820";
in
{
  # boot.extraModulePackages = [ config.boot.kernelPackages.wireguard ];

  systemd.network = {
    netdevs = {
      "99-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
          MTUBytes = "1300";
        };

        # See also man systemd.netdev (also contains info on the permissions of the key files)
        wireguardConfig = {
          # Don't use a file from the Nix store as these are world readable. Must be readable by the systemd.network user
          PrivateKeyFile = PRIVATEKEYFILE;
          # ListenPort = 9918;
        };

        wireguardPeers = [
          # configuration since nixos-unstable/nixos-24.11
          {
            PublicKey = PUBLICKEY;
            AllowedIPs = ALLOWEDIPS;
            Endpoint = ENDPOINT;
          }
          # configuration for nixos 24.05
          #{
          #  wireguardPeerConfig = {
          #    PublicKey = "OhApdFoOYnKesRVpnYRqwk3pdM247j8PPVH5K7aIKX0=";
          #    AllowedIPs = ["fc00::1/64" "10.100.0.1"];
          #    Endpoint = "{set this to the server ip}:51820";
          #  };
          #}
        ];
      };
    };
    networks.wg0 = {
      # See also man systemd.network
      matchConfig.Name = "wg0";
      # IP addresses the client interface will have
      address = ADDRESS;
      DHCP = "no";
      dns = DNS;
      ntp = [ "fc00::123" ];
      gateway = ALLOWEDIPS;
      networkConfig = { IPv6AcceptRA = false; };
    };
  };

  sops.secrets."general/wireguardKeyFile" = { };
}
