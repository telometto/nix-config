{ lib, ... }:
{
  # Preparation only. Resume the independent Flux layers only after an
  # explicitly reviewed host deployment; production searx stays enabled.
  sys.virtualisation.actualPilot.previewVMs.searx-preview = {
    enable = lib.mkDefault false;
    disks = [ "root" ];
  };
}
