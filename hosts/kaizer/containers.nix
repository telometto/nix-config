# Rootless Podman containers on kaizer (managed via quadlet-nix + Home Manager)
{ VARS, consts, ... }:
let
  username = VARS.users.luke.user;
in
{
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    consts.ports.secondary.immichMachineLearning.hostPort
  ];

  users.users.${username} = {
    linger = true;
    autoSubUidGidRange = true;
    extraGroups = [
      "video"
      "render"
    ];
  };

  home-manager.users.${username} = {
    imports = [
      ../../containers/immich-machine-learning.nix
    ];

    services.immich-machine-learning-container = {
      enable = true;
      port = consts.ports.secondary.immichMachineLearning.hostPort;
      acceleration = "cuda";
    };
  };
}
