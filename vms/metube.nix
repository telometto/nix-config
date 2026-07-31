{ inputs, ... }:
let
  reg = (import ./vm-registry.nix).metube;
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
    ../modules/services/metube.nix
    ../modules/virtualisation/virtualisation.nix
    inputs.quadlet-nix.nixosModules.quadlet
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/metube";
            image = "metube-state.img";
            size = 256;
          }
          {
            mountPoint = "/var/lib/containers";
            image = "containers-storage.img";
            size = 2048;
          }
        ];
        extraShares = [ mediaShare ];
        extraRoutes = vpnRoutes;
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/containers/tmp 0750 root root -"
    ];

    # Keep image-pull scratch data off the guest's small root tmpfs.
    services.metube.environment.TMPDIR = "/var/lib/containers/tmp";
  };

  sys = {
    virtualisation.enable = true;

    services.metube = {
      enable = true;
      inherit (reg) port;
      downloadDir = "/data/downloads/metube";
      stateDir = "/var/lib/metube";
      uid = 1000;
      gid = 100;
      maxConcurrentDownloads = 4;
      openFirewall = false;
    };
  };
}
