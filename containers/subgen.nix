# Subgen: automatic subtitle generation via Whisper
{ lib, ... }:
{
  options.sys.virtualisation.podman.stacks.subgen = {
    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/media/data/media";
      description = "Base path for media directories (movies/, tv/).";
    };

    modelDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/docker/subgen/models";
      description = "Path for Whisper model storage.";
    };
  };

  config.sys.virtualisation.podman.stacks.subgen = {
    containers = {
      subgen = {
        image = "mccloud/subgen";
        ports = [ "11027:9000" ];
        environment = {
          WHISPER_MODEL = "medium";
          WHISPER_THREADS = "6";
          PROCADDEDMEDIA = "True";
          PROCMEDIAONPLAY = "False";
          NAMESUBLANG = "eng";
          SKIPIFINTERNALSUBLANG = "eng";
          WEBHOOKPORT = "9000";
          CONCURRENT_TRANSCRIPTIONS = "2";
          WORD_LEVEL_HIGHLIGHT = "False";
          DEBUG = "True";
          TRANSCRIBE_DEVICE = "cpu";
          CLEAR_VRAM_ON_COMPLETE = "True";
          MODEL_PATH = "./models";
          UPDATE = "True";
          APPEND = "False";
          USE_MODEL_PROMPT = "False";
          CUSTOM_MODEL_PROMPT = "";
          LRC_FOR_AUDIO_FILES = "True";
          CUSTOM_REGROUP = "cm_sl=84_sl=42++++++1";
          USE_PATH_MAPPING = "True";
          PATH_MAPPING_FROM = "/rpool/unenc/media/data";
          PATH_MAPPING_TO = "/data";
          # TODO: migrate these tokens to sops-nix environmentFiles
          PLEXSERVER = "https://192.168.2.100:32400";
          JELLYFINSERVER = "http://192.168.2.100:8096";
        };
        volumes = [
          "/rpool/unenc/media/data/media/tv:/data/media/tv"
          "/rpool/unenc/media/data/media/movies:/data/media/movies"
          "/rpool/unenc/apps/docker/subgen/models:/subgen/models"
        ];
        extraOptions = [
          "--tty"
          "--security-opt=apparmor:unconfined"
        ];
      };
    };
  };
}
