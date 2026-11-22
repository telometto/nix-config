{ ... }:
{
  imports = [ (import ./mkArrVm.nix { name = "sonarr"; }) ];

  sys.services.arrExporter.sonarr.extraEnvironment.ENABLE_ADDITIONAL_METRICS = "true";
}
