let
  sharedBridge = {
    name = "microvm-br0";
    address = "10.100.0.1";
    prefixLength = 24;
    network = "10.100.0.0/24";
  };

  # mkMicrovmConfig assigns this name to the NIC matched by the VM's fixed MAC.
  # The stable name avoids trusting a predictable-name suffix that can change
  # when Cloud Hypervisor's device layout changes.
  guestInterface = "microvm0";
in
{
  inherit sharedBridge guestInterface;
  defaultGateway = sharedBridge.address;
  defaultPrefixLength = sharedBridge.prefixLength;
}
