# Fresh preview disks only; runtime and Flux stay gated separately.
{ lib, ... }:
{
  sys.virtualisation.actualPilot.previewVMs.gitea-preview = {
    enable = lib.mkDefault false;
    disks = [
      "root"
      "data"
      "postgresql"
    ];
  };
}
