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

  networking.firewall.allowedTCPPorts = [ flaresolverrPort ];
  services.flaresolverr = {
    enable = true;
    port = flaresolverrPort;
  };

  sys.services.arrExporter.prowlarr.extraEnvironment.ENABLE_ADDITIONAL_METRICS = "true";
}
