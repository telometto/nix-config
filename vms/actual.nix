{ ... }:
let
  reg = (import ./vm-registry.nix).actual;
in
{
  imports = [
    ./base.nix
    ../modules/services/actual.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        # NOTE: Actual uses DynamicUser=true, requiring /var/lib/private/
        volumes = [
          {
            mountPoint = "/var/lib/private/actual";
            image = "actual-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  sys.services.actual = {
    enable = true;
    port = reg.port;
    dataDir = "/var/lib/actual";
  };
}
