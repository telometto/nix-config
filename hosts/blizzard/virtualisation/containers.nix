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
      ../../../containers/nominatim.nix
    ];

    services = {
      lingarr = {
        enable = true;
        ollama.enable = false;
      };

      nominatim-container = {
        enable = true;
        replicationUrl = "https://download.geofabrik.de/europe/norway-updates/";
      };

      subgen = {
        enable = false;
        plexServer = "https://192.168.2.100:32400";
        transcribeOrTranslate = "translate";
        subtitleLanguageName = "en";
        preferredAudioLanguages = "eng|nor";
      };
    };
  };
}
