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
  prefixLength ? 24,
  mem,
  vcpu ? 1,
  gateway ? "10.100.0.1",
  dns ? "1.1.1.1",
  tapId ? "vm-${name}",
  hostBridge ? null,
  volumes ? [ ],
  extraShares ? [ ],
  extraRoutes ? [ ],
  ...
}:
{ lib, ... }:
let
  ipv4 = import ./ipv4.nix;
  prefixIsValid = ipv4.validPrefix prefixLength && prefixLength >= 1 && prefixLength <= 31;
  parsedIp = ipv4.parse ip;
  parsedGateway = ipv4.parse gateway;
  ipIsUsable = prefixIsValid && ipv4.usableHostAddress ip prefixLength;
  gatewayIsUsable = prefixIsValid && ipv4.usableHostAddress gateway prefixLength;
  addressesShareSubnet = ipv4.sameSubnet ip gateway prefixLength;
  sharedNetwork = ipv4.networkInterval "10.100.0.0" 24;
  configuredNetwork = ipv4.networkInterval ip prefixLength;
  sharedNetworkMatches =
    !prefixIsValid
    || parsedIp == null
    || hostBridge != null
    || (
      configuredNetwork != null && prefixLength == 24 && configuredNetwork.first == sharedNetwork.first
    );
in
{
  assertions = [
    {
      assertion = prefixIsValid;
      message = "mkMicrovmConfig (${name}): prefixLength must be an integer between 1 and 31";
    }
    {
      assertion = parsedIp != null;
      message = "mkMicrovmConfig (${name}): ip must be a valid IPv4 address";
    }
    {
      assertion = parsedGateway != null;
      message = "mkMicrovmConfig (${name}): gateway must be a valid IPv4 address";
    }
    {
      assertion = !prefixIsValid || parsedIp == null || parsedGateway == null || addressesShareSubnet;
      message = "mkMicrovmConfig (${name}): ip and gateway must share the configured IPv4 subnet";
    }
    {
      assertion = !prefixIsValid || parsedIp == null || ipIsUsable;
      message = "mkMicrovmConfig (${name}): ip must be a usable host address, not a network or broadcast endpoint";
    }
    {
      assertion = !prefixIsValid || parsedGateway == null || gatewayIsUsable;
      message = "mkMicrovmConfig (${name}): gateway must be a usable host address, not a network or broadcast endpoint";
    }
    {
      assertion = parsedIp == null || parsedGateway == null || parsedIp != parsedGateway;
      message = "mkMicrovmConfig (${name}): ip and gateway must be different addresses";
    }
    {
      assertion = sharedNetworkMatches;
      message = "mkMicrovmConfig (${name}): non-dedicated VMs must use the shared 10.100.0.0/24 network";
    }
  ];

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
    # Match the VM's primary NIC by its fixed MAC address so only the virtio
    # interface gets the static LAN config; no other interface (Docker veth,
    # future ether device, etc.) can accidentally match this unit.
    matchConfig.MACAddress = mac;
    networkConfig = {
      Address = [ "${ip}/${toString prefixLength}" ];
      Gateway = gateway;
      DNS = [ dns ];
      DHCP = "no";
    };
  }
  // lib.optionalAttrs (extraRoutes != [ ]) { routes = extraRoutes; };

  # Explicitly tell systemd-networkd to leave Docker veth and bridge
  # interfaces unmanaged so Docker can configure them freely.
  systemd.network.networks."99-docker-ignore" = {
    matchConfig.Name = "veth* br-* docker*";
    linkConfig.Unmanaged = true;
  };
}
