# Rootless Podman containers on blizzard (managed via quadlet-nix + Home Manager)
{
  lib,
  config,
  VARS,
  ...
}:
let
  username = VARS.users.zeno.user;
  homeEnabled = config.sys.home.enable && (config.sys.home.users.${username}.enable or true);
in
{
  users.users.${username} = {
    linger = true;
    autoSubUidGidRange = true;
  };

  home-manager.users.${username} = lib.mkIf homeEnabled {
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
        enable = false;
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
