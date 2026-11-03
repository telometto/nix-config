{ consts, ... }:
let
  reg = (import ./vm-registry.nix { inherit consts; }).sabnzbd;
  mediaStorage = import ./media-storage.nix;
  networkDefaults = import ./microvm-network-defaults.nix;
in
{
  imports = [
    ./base.nix
    ../modules/services/sabnzbd.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/sabnzbd";
            image = "sabnzbd-state.img";
            size = 10240;
          }
        ];
        extraShares = [ mediaStorage.share ];
        extraRoutes = networkDefaults.vpnReturnRoutes;
      }
    ))
  ];

  nixpkgs.config.allowUnfree = true;

  networking.firewall.allowedTCPPorts = [ reg.port ];

  sys.services.sabnzbd = {
    enable = true;
    inherit (reg) port;
    dataDir = "/var/lib/sabnzbd";
    openFirewall = false;
  };
}
