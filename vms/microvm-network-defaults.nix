let
  sharedBridge = {
    name = "microvm-br0";
    address = "10.100.0.1";
    prefixLength = 24;
    network = "10.100.0.0/24";
  };

  # The current Cloud Hypervisor guest layout exposes the primary virtio NIC
  # at PCI slot 6, which systemd names ens6. Keep firewall rules that target
  # the VM's primary network boundary on this shared contract instead of
  # scattering the device name through workloads.
  guestInterface = "ens6";
in
{
  inherit sharedBridge guestInterface;
  defaultGateway = sharedBridge.address;
  defaultPrefixLength = sharedBridge.prefixLength;
}
