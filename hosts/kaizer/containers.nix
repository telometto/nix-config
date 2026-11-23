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
