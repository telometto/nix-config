# Subtitle processing pod: Lingarr (+ LibreTranslate, Ollama) and Subgen
# Home Manager module — containers run rootless via quadlet-nix in a shared pod
{ lib, config, ... }:
let
  cfgLingarr = config.services.lingarr;
  cfgSubgen = config.services.subgen;
  anyEnabled = cfgLingarr.enable || cfgSubgen.enable;
  inherit (config.virtualisation.quadlet) pods containers;
in
{
  options.services.lingarr = {
    enable = lib.mkEnableOption "Lingarr subtitle translation stack";

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/media/data/media";
      description = "Base path for media directories (movies/, tv/).";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/docker";
      description = "Base path for persistent application data.";
    };
  };

  options.services.subgen = {
    enable = lib.mkEnableOption "Subgen Whisper subtitle generation";

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

    plexServer = lib.mkOption {
      type = lib.types.str;
      default = "https://192.168.2.100:32400";
      description = "Plex server URL (including port).";
    };

    jellyfinServer = lib.mkOption {
      type = lib.types.str;
      default = "http://192.168.2.100:8096";
      description = "Jellyfin server URL (including port).";
    };
  };

  config = lib.mkIf anyEnabled {
    sops = lib.mkIf cfgSubgen.enable {
      secrets = {
        "plex/server_token" = { };
        "jellyfin/server_token" = { };
      };

      templates."subgen-tokens".content = ''
        PLEXTOKEN=${config.sops.placeholder."plex/server_token"}
        JELLYFINTOKEN=${config.sops.placeholder."jellyfin/server_token"}
      '';
    };

    virtualisation.quadlet = {
      pods.subtitle-stack = {
        podConfig.userns = "keep-id";
        podConfig.publishPorts =
          lib.optionals cfgLingarr.enable [
            "11025:9876"
            "11026:5000"
            "11434:11434"
          ]
          ++ lib.optionals cfgSubgen.enable [
            "11027:9000"
          ];
      };

      containers = lib.mkMerge [
        (lib.mkIf cfgLingarr.enable {
          lingarr = {
            autoStart = true;
            containerConfig = {
              image = "lingarr/lingarr:latest";
              environments = {
                ASPNETCORE_URLS = "http://+:9876";
                MAX_CONCURRENT_JOBS = "1";
                DB_HANGFIRE_SQLITE_PATH = "/app/config/Hangfire.db";
              };
              volumes = [
                "${cfgLingarr.mediaDir}/movies:/data/media/movies"
                "${cfgLingarr.mediaDir}/tv:/data/media/tv"
                "${cfgLingarr.dataDir}/lingarr:/app/config"
              ];
              pod = pods.subtitle-stack.ref;
            };
            unitConfig = {
              Requires = [
                containers.libretranslate.ref
                containers.ollama.ref
              ];
              After = [
                containers.libretranslate.ref
                containers.ollama.ref
              ];
            };
          };

          libretranslate = {
            autoStart = true;
            containerConfig = {
              image = "libretranslate/libretranslate:latest";
              environments = {
                LT_LOAD_ONLY = "en,it,nb";
              };
              volumes = [
                "${cfgLingarr.dataDir}/libretranslate:/home/libretranslate/.local/share/argos-translate"
              ];
              pod = pods.subtitle-stack.ref;
            };
          };

          ollama = {
            autoStart = true;
            containerConfig = {
              image = "ollama/ollama:latest";
              volumes = [
                "${cfgLingarr.dataDir}/ollama:/root/.ollama"
              ];
              pod = pods.subtitle-stack.ref;
            };
          };
        })

        (lib.mkIf cfgSubgen.enable {
          subgen = {
            autoStart = true;
            containerConfig = {
              image = "mccloud/subgen";
              environments = {
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
                PATH_MAPPING_FROM = lib.dirOf cfgSubgen.mediaDir;
                PATH_MAPPING_TO = "/data";
                PLEXSERVER = cfgSubgen.plexServer;
                JELLYFINSERVER = cfgSubgen.jellyfinServer;
              };
              volumes = [
                "${cfgSubgen.mediaDir}/tv:/data/media/tv"
                "${cfgSubgen.mediaDir}/movies:/data/media/movies"
                "${cfgSubgen.modelDir}:/subgen/models"
              ];
              environmentFiles = [
                config.sops.templates."subgen-tokens".path
              ];
              podmanArgs = [ "--tty" ];
              pod = pods.subtitle-stack.ref;
            };
          };
        })
      ];
    };
  };
}
