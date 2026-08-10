let
  sharedBridge = {
    name = "microvm-br0";
    address = "10.100.0.1";
    prefixLength = 24;
    network = "10.100.0.0/24";
  };
in
{
  inherit sharedBridge;
  defaultGateway = sharedBridge.address;
  defaultPrefixLength = sharedBridge.prefixLength;
}
