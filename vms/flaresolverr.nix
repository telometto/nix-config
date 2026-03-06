{ ... }:
let
  reg = (import ./vm-registry.nix).flaresolverr;
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
    port = reg.port;
    openFirewall = false;
  };
}
