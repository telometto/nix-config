# Rootless Podman containers on blizzard (managed via quadlet-nix + Home Manager)
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
      ../../../containers/subtitle-stack.nix
    ];

    services = {
      lingarr = {
        enable = true;
        ollama.enable = false;
      };
      subgen = {
        enable = true;
        plexServer = "https://192.168.2.100:32400";
      };
    };
  };
}
