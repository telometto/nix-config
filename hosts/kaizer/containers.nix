# Rootless Podman containers on kaizer (managed via quadlet-nix + Home Manager)
{ VARS, consts, ... }:
let
  username = VARS.users.luke.user;
  mlFirewall = import ../../lib/immich-ml-firewall.nix {
    blizzardIPv4 = consts.tailscale.hosts.blizzard.ipv4;
    port = consts.ports.secondary.immichMachineLearning.hostPort;
  };
in
{
  networking.firewall = mlFirewall;

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
