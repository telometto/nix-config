{
  # Enable the VM service without importing old host state; leave that state on disk.
  # The host service is disabled when this configuration is activated.
  vmServiceReady = true;
  # Publish only after private setup, capacity checks, and source guard tests.
  vpsIPv4 = "100.98.54.14";
  # Direct home-LAN access through Blizzard's existing MicroVM port forward.
  # Set to null during private first-run setup or to disable LAN access.
  lanIPv4Subnet = "192.168.2.0/24";

  # A future dedicated card must be checked for IOMMU group isolation and
  # configured with its guest driver before this is enabled. Never bind the
  # current iGPU to VFIO as part of the initial migration.
  gpuPassthrough = {
    enable = false;
    pciFunctions = [ ];
  };
}
