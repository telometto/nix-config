{ ... }:
{
  imports = [ (import ./mkArrVm.nix { name = "bazarr"; }) ];

  sys.services.arrExporter.bazarr.extraEnvironment.ENABLE_ADDITIONAL_METRICS = "true";
}
