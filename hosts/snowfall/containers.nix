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
      ../../containers/subgen.nix
    ];

    services = {
      ollama-container = {
        enable = true;
        dataDir = "/home/${username}/.local/share/ollama";
        gpu.enable = true;
      };

      subgen-container = {
        enable = true;
        gpu.enable = true;
        whisperModel = "large-v3";
        mediaDir = "/home/${username}/pools/rpool/unenc/media/data/media";

        plexServer = "https://192.168.2.100:32400";
        transcribeOrTranslate = "translate";
        subtitleLanguageName = "en";
        preferredAudioLanguages = "eng|nor";
      };
    };
  };
}
