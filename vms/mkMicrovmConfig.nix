# Helper that generates common MicroVM infrastructure config.
# Returns a NixOS module setting microvm, networking, and systemd.network.
#
# Usage in a VM file:
#   imports = [
#     ./base.nix
#     (import ./mkMicrovmConfig.nix (registry.myvm // {
#       volumes = [ { mountPoint = "/var/lib/myservice"; image = "state.img"; size = 10240; } ];
#     }))
#   ];
#
# The /persist volume and /nix/store share are appended automatically.
# Caller only needs to provide service-specific volumes and shares.
{
  name,
  cid,
  mac,
  ip,
  mem,
  vcpu ? 1,
  gateway ? "10.100.0.1",
  dns ? "1.1.1.1",
  tapId ? "vm-${name}",
  volumes ? [ ],
  extraShares ? [ ],
  extraRoutes ? [ ],
  ...
}:
{ lib, ... }:
{
  microvm = {
    hypervisor = "cloud-hypervisor";
    vsock.cid = cid;
    inherit mem vcpu;

    volumes = volumes ++ [
      {
        mountPoint = "/persist";
        image = "persist.img";
        size = 64;
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = tapId;
        inherit mac;
      }
    ];

    shares = [
      {
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag = "ro-store";
        proto = "virtiofs";
      }
    ]
    ++ extraShares;
  };

  networking = {
    hostName = "${name}-vm";
    useDHCP = false;
    useNetworkd = true;
    firewall.enable = true;
  };

  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [ "${ip}/24" ];
      Gateway = gateway;
      DNS = [ dns ];
      DHCP = "no";
    };
  }
  // lib.optionalAttrs (extraRoutes != [ ]) { routes = extraRoutes; };
}
