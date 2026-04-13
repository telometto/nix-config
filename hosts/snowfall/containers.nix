# Rootless Podman containers on snowfall (managed via quadlet-nix + Home Manager)
{ VARS, pkgs, ... }:
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
        dataDir = "/run/media/${username}/personal/container-models/ollama/";
        gpu.enable = true;
      };

      subgen-container = {
        enable = false;
        gpu.enable = true;
        whisperModel = "large-v3";
        mediaDir = "/home/${username}/pools/rpool/unenc/media/data/media";
        modelDir = "/run/media/${username}/personal/container-models/subgen";

        plexServer = "https://192.168.2.100:32400";
        transcribeOrTranslate = "translate";
        subtitleLanguageName = "en";
        preferredAudioLanguages = "eng|nor";
      };
    };
  };
}
