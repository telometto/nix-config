{ consts, ... }:
let
  reg = (import ./vm-registry.nix { inherit consts; }).flaresolverr;
in
{
  imports = [
    ./base.nix
    ../modules/services/flaresolverr.nix
    (import ./mkMicrovmConfig.nix reg)
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  sys.services.flaresolverr = {
    enable = true;
    inherit (reg) port;
    openFirewall = false;
  };
}
