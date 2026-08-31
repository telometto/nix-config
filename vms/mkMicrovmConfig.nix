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
# The /persist volume and /nix/store share are appended automatically. A caller
# may override persistVolume when storage metadata is shared with another
# consumer, such as a backup job.
let
  networkDefaults = import ./microvm-network-defaults.nix;
in
{
  name,
  cid,
  mac,
  ip,
  prefixLength ? networkDefaults.defaultPrefixLength,
  mem,
  vcpu ? 1,
  gateway ? networkDefaults.defaultGateway,
  dns ? "1.1.1.1",
  tapId ? "vm-${name}",
  hostBridge ? null,
  volumes ? [ ],
  persistVolume ? {
    mountPoint = "/persist";
    image = "persist.img";
    size = 64;
  },
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
  sharedNetwork = ipv4.networkInterval networkDefaults.sharedBridge.address networkDefaults.sharedBridge.prefixLength;
  configuredNetwork = ipv4.networkInterval ip prefixLength;
  sharedNetworkMatches =
    !prefixIsValid
    || parsedIp == null
    || hostBridge != null
    || (
      configuredNetwork != null
      && prefixLength == networkDefaults.sharedBridge.prefixLength
      && configuredNetwork.first == sharedNetwork.first
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
      message = "mkMicrovmConfig (${name}): non-dedicated VMs must use the shared ${networkDefaults.sharedBridge.network} network";
    }
  ];

  microvm = {
    hypervisor = "cloud-hypervisor";
    vsock.cid = cid;
    inherit mem vcpu;

    volumes = volumes ++ [ persistVolume ];

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

  # Cloud Hypervisor can assign a different predictable name when the device
  # layout changes. Match the fixed VM MAC and assign one stable guest name so
  # firewall rules do not need an interface-name wildcard.
  systemd = {
    network = {
      links."10-microvm-primary" = {
        matchConfig.MACAddress = mac;
        linkConfig.Name = networkDefaults.guestInterface;
      };

      networks = {
        "20-lan" = {
          # Match the VM's primary NIC by its fixed MAC address so only the
          # virtio interface gets the static LAN config; no other interface
          # (Docker veth, future ether device, etc.) can accidentally match
          # this unit.
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
        "99-docker-ignore" = {
          matchConfig.Name = "veth* br-* docker*";
          linkConfig.Unmanaged = true;
        };
      };
    };
  };
}
