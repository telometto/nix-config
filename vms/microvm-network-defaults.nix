let
  sharedBridge = {
    name = "microvm-br0";
    address = "10.100.0.1";
    prefixLength = 24;
    network = "10.100.0.0/24";
  };

  # Cloud Hypervisor exposes the primary virtio NIC as ens3 in guests. Keep
  # firewall rules that target the VM's primary network boundary on this
  # shared contract instead of scattering the device name through workloads.
  guestInterface = "ens3";
in
{
  inherit sharedBridge guestInterface;
  defaultGateway = sharedBridge.address;
  defaultPrefixLength = sharedBridge.prefixLength;
}
