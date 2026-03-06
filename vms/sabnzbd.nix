_:
let
  reg = (import ./vm-registry.nix).sabnzbd;
  mediaShare = {
    source = "/rpool/unenc/media/data";
    mountPoint = "/data";
    tag = "media-data";
    proto = "virtiofs";
  };
  vpnRoutes = [
    {
      Gateway = "10.100.0.1";
      Destination = "192.168.0.0/16";
    }
    {
      Gateway = "10.100.0.1";
      Destination = "10.100.0.0/24";
    }
  ];
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
        extraShares = [ mediaShare ];
        extraRoutes = vpnRoutes;
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
