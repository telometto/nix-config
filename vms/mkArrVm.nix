{
  name,
  media ? true,
}:
{ consts, ... }:
let
  reg = (import ./vm-registry.nix { inherit consts; }).${name};
  mediaStorage = import ./media-storage.nix;
  dataDir = "/var/lib/${name}";
in
{
  imports = [
    ./base.nix
    ../modules/services/${name}.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = dataDir;
            image = "${name}-state.img";
            size = 10240;
          }
        ];
        extraShares = if media then [ mediaStorage.share ] else [ ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];
  systemd.tmpfiles.rules = [ "d ${dataDir} 0700 ${name} ${name} -" ];

  sys.services.${name} = {
    enable = true;
    inherit (reg) port;
    inherit dataDir;
    reverseProxy.enable = false;
  };

  sys.services.arrExporter.${name} = {
    enable = true;
    openFirewall = true;
    arrPort = reg.port;
  };
}
