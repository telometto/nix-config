# Fresh preview disks only; runtime and Flux stay gated separately.
{ lib, ... }:
{
  sys.virtualisation.actualPilot.previewVMs.prowlarr-preview = {
    enable = lib.mkDefault false;
    disks = [
      "root"
      "data"
    ];
  };
}
