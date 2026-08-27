let
  sharedBridge = {
    name = "microvm-br0";
    address = "10.100.0.1";
    prefixLength = 24;
    network = "10.100.0.0/24";
  };

  # Cloud Hypervisor's virtio device ordering can shift when a guest gains a
  # persistent volume, so systemd may expose the primary NIC as ens6, ens7,
  # and so on. iptables accepts a trailing + as an interface-name wildcard.
  guestInterface = "ens+";
in
{
  inherit sharedBridge guestInterface;
  defaultGateway = sharedBridge.address;
  defaultPrefixLength = sharedBridge.prefixLength;
}
