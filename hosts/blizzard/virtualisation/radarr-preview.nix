# Fresh preview disks only; runtime and Flux stay gated separately.
{ lib, ... }:
{
  sys.virtualisation.actualPilot.previewVMs.radarr-preview = {
    enable = lib.mkDefault false;
    disks = [
      "root"
      "data"
    ];
  };
}
