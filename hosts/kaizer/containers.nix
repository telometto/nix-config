# Rootless Podman containers on kaizer (managed via quadlet-nix + Home Manager)
{ VARS, ... }:
let
  username = VARS.users.luke.user;
  immichMlPort = 3003;
in
{
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ immichMlPort ];

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
      port = immichMlPort;
      acceleration = "cuda";
    };
  };
}
