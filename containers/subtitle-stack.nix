# Subtitle processing pod: Lingarr (+ LibreTranslate, Ollama) and Subgen
# Home Manager module - containers run rootless via quadlet-nix in a shared pod
{ lib, config, ... }:
let
  cfgLingarr = config.services.lingarr;
  cfgSubgen = config.services.subgen;
  anyEnabled = cfgLingarr.enable || cfgSubgen.enable;
  hasPlex = cfgSubgen.enable && cfgSubgen.plexServer != null;
  hasJellyfin = cfgSubgen.enable && cfgSubgen.jellyfinServer != null;
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

    libretranslate.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run LibreTranslate in the subtitle-stack pod.";
    };

    ollama.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run Ollama in the subtitle-stack pod. Disable when using a remote instance.";
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
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Plex server URL. Set to null to disable Plex integration.";
    };

    jellyfinServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Jellyfin server URL. Set to null to disable Jellyfin integration.";
    };

    whisperModel = lib.mkOption {
      type = lib.types.str;
      default = "medium";
      description = "Whisper model to use (tiny, base, small, medium, large-v3, large-v3-turbo, etc.). large-v3-turbo does not support translation.";
    };

    transcribeOrTranslate = lib.mkOption {
      type = lib.types.enum [
        "transcribe"
        "translate"
      ];
      default = "transcribe";
      description = "Whether to transcribe (keep original language) or translate foreign audio to English.";
    };

    subtitleLanguageName = lib.mkOption {
      type = lib.types.str;
      default = "aa";
      description = "ISO 639-1 two-letter code used in the output subtitle filename (e.g., en, no). Defaults to 'aa' to float to the top of Plex's list.";
    };

    preferredAudioLanguages = lib.mkOption {
      type = lib.types.str;
      default = "eng";
      description = "Pipe-separated ISO 639-2 three-letter codes (e.g., eng|nor). Prefer transcribing these audio tracks when multiple exist.";
    };

    forceDetectedLanguageTo = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Force Whisper to a specific ISO 639-1 two-letter code (e.g., en, no) if auto-detection is unreliable.";
    };
  };

  config = lib.mkIf anyEnabled {
    assertions = [
      {
        assertion =
          !(
            cfgSubgen.enable
            && cfgSubgen.transcribeOrTranslate == "translate"
            && lib.hasSuffix "turbo" cfgSubgen.whisperModel
          );
        message = "Whisper models ending in 'turbo' do not support translation - use a non-turbo model when transcribeOrTranslate is 'translate'.";
      }
    ];

    sops = lib.mkIf (hasPlex || hasJellyfin) {
      secrets = lib.mkMerge [
        (lib.mkIf hasPlex { "plex/server_token" = { }; })
        (lib.mkIf hasJellyfin { "jellyfin/server_token" = { }; })
      ];

      templates."subgen-tokens".content = lib.concatStrings (
        lib.optional hasPlex "PLEXTOKEN=${config.sops.placeholder."plex/server_token"}\n"
        ++ lib.optional hasJellyfin "JELLYFINTOKEN=${config.sops.placeholder."jellyfin/server_token"}\n"
      );
    };

    virtualisation.quadlet = {
      pods.subtitle-stack = {
        podConfig.userns = "keep-id";
        podConfig.publishPorts =
          lib.optionals cfgLingarr.enable [
            "11025:9876"
          ]
          ++ lib.optionals (cfgLingarr.enable && cfgLingarr.libretranslate.enable) [
            "11026:5000"
          ]
          ++ lib.optionals (cfgLingarr.enable && cfgLingarr.ollama.enable) [
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
              image = "docker.io/lingarr/lingarr:latest";
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
              Requires =
                lib.optional cfgLingarr.libretranslate.enable containers.libretranslate.ref
                ++ lib.optional cfgLingarr.ollama.enable containers.ollama.ref;
              After =
                lib.optional cfgLingarr.libretranslate.enable containers.libretranslate.ref
                ++ lib.optional cfgLingarr.ollama.enable containers.ollama.ref;
            };
          };
        })

        (lib.mkIf (cfgLingarr.enable && cfgLingarr.libretranslate.enable) {
          libretranslate = {
            autoStart = true;
            containerConfig = {
              image = "docker.io/libretranslate/libretranslate:latest";
              environments = {
                LT_LOAD_ONLY = "en,it,nb";
              };
              volumes = [
                "${cfgLingarr.dataDir}/libretranslate:/home/libretranslate/.local/share/argos-translate"
              ];
              pod = pods.subtitle-stack.ref;
            };
          };
        })

        (lib.mkIf (cfgLingarr.enable && cfgLingarr.ollama.enable) {
          ollama = {
            autoStart = true;
            containerConfig = {
              image = "docker.io/ollama/ollama:latest";
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
              image = "docker.io/mccloud/subgen";
              environments = {
                WHISPER_MODEL = cfgSubgen.whisperModel;
                WHISPER_THREADS = "6";
                PROCADDEDMEDIA = "True";
                PROCMEDIAONPLAY = "False";
                TRANSCRIBE_OR_TRANSLATE = cfgSubgen.transcribeOrTranslate;
                SUBTITLE_LANGUAGE_NAME = cfgSubgen.subtitleLanguageName;
                PREFERRED_AUDIO_LANGUAGES = cfgSubgen.preferredAudioLanguages;
                SKIPIFINTERNALSUBLANG = "eng";
                WEBHOOKPORT = "9000";
                CONCURRENT_TRANSCRIPTIONS = "2";
                WORD_LEVEL_HIGHLIGHT = "False";
                DEBUG = "False";
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
              }
              // lib.optionalAttrs (cfgSubgen.forceDetectedLanguageTo != "") {
                FORCE_DETECTED_LANGUAGE_TO = cfgSubgen.forceDetectedLanguageTo;
              }
              // lib.optionalAttrs hasPlex {
                PLEXSERVER = cfgSubgen.plexServer;
              }
              // lib.optionalAttrs hasJellyfin {
                JELLYFINSERVER = cfgSubgen.jellyfinServer;
              };
              volumes = [
                "${cfgSubgen.mediaDir}/tv:/data/media/tv"
                "${cfgSubgen.mediaDir}/movies:/data/media/movies"
                "${cfgSubgen.modelDir}:/subgen/models"
              ];
              environmentFiles = lib.optionals (hasPlex || hasJellyfin) [
                config.sops.templates."subgen-tokens".path
              ];
              podmanArgs = [ "--tty" ];
              pod = pods.subtitle-stack.ref;
            };

            unitConfig = lib.mkIf (hasPlex || hasJellyfin) {
              Requires = [ "sops-nix.service" ];
              After = [ "sops-nix.service" ];
            };
          };
        })
      ];
    };
  };
}
