# Rootless Podman containers on snowfall (managed via quadlet-nix + Home Manager)
{ VARS, ... }:
let
  username = VARS.users.zeno.user;
in
{
  users.users.${username} = {
    linger = true;
    autoSubUidGidRange = true;
  };

  home-manager.users.${username} = {
    imports = [
      ../../containers/ollama.nix
    ];

    services.ollama-container = {
      enable = true;
      dataDir = "/home/${username}/.local/share/ollama";
    };
  };
}
