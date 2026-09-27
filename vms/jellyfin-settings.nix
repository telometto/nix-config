{
  # Activate only after a stopped-state copy into jellyfin-vm has been checked.
  # The VM and its volumes can be prepared while Jellyfin continues on Blizzard.
  vmServiceReady = false;
  # Publish only after private setup, capacity checks, and source guard tests.
  vpsIPv4 = null;

  # A future dedicated card must be checked for IOMMU group isolation and
  # configured with its guest driver before this is enabled. Never bind the
  # current iGPU to VFIO as part of the initial migration.
  gpuPassthrough = {
    enable = false;
    pciFunctions = [ ];
  };
}
