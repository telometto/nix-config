# Rootless Podman containers on kaizer (managed via quadlet-nix + Home Manager)
{
  lib,
  config,
  VARS,
  consts,
  ...
}:
let
  username = VARS.users.luke.user;
  homeEnabled = config.sys.home.enable && (config.sys.home.users.${username}.enable or true);
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

  home-manager.users.${username} = lib.mkIf homeEnabled {
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
