{ consts, ... }:
let
  flaresolverrPort = (import ./vm-registry.nix { inherit consts; }).flaresolverr.port;
in
{
  imports = [
    (import ./mkArrVm.nix {
      name = "prowlarr";
      media = false;
    })
  ];

  services.flaresolverr = {
    enable = true;
    port = flaresolverrPort;
  };
  systemd.services.flaresolverr.environment.HOST = "127.0.0.1";

  sys.services.arrExporter.prowlarr.extraEnvironment.ENABLE_ADDITIONAL_METRICS = "true";
}
