# Standalone Subgen container — can run on any host independently
# Home Manager module — runs rootless via quadlet-nix
# Uses mccloud/subgen:cpu by default, mccloud/subgen:amd when gpu.enable is true
{ lib, config, ... }:
let
  cfg = config.services.subgen-container;
  hasPlex = cfg.plexServer != null;
  hasJellyfin = cfg.jellyfinServer != null;
in
{
  options.services.subgen-container = {
    enable = lib.mkEnableOption "Standalone Subgen subtitle generation container";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Host port to expose the Subgen webhook listener on.";
    };

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/media/data/media";
      description = "Base path for media directories (movies/, tv/).";
    };

    modelDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/docker/subgen/models";
      description = "Path for persistent Whisper model storage.";
    };

    image = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Container image to use. Defaults to mccloud/subgen:amd when gpu.enable is true, mccloud/subgen:cpu otherwise.";
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
      description = "Language code used in the output subtitle filename (e.g., en, no).";
    };

    preferredAudioLanguages = lib.mkOption {
      type = lib.types.str;
      default = "eng";
      description = "Pipe-separated ISO 639-2 codes. Prefer transcribing these audio tracks when multiple exist.";
    };

    forceDetectedLanguageTo = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Force Whisper to a specific 2-letter language code if auto-detection is unreliable.";
    };

    whisperThreads = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of CPU threads for Whisper computation.";
    };

    concurrentTranscriptions = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Number of files to process in parallel.";
    };

    plexServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Plex server URL (e.g. http://192.168.1.100:32400). Set to null to disable Plex integration.";
    };

    jellyfinServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Jellyfin server URL. Set to null to disable Jellyfin integration.";
    };

    extraEnvironments = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for the Subgen container.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Paths to environment files (e.g. SOPS-rendered templates) containing secrets like PLEXTOKEN or JELLYFINTOKEN.";
    };

    gpu = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Pass through AMD GPU (/dev/dri, /dev/kfd) for ROCm hardware acceleration.";
      };

      hsaOverrideGfxVersion = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "HSA_OVERRIDE_GFX_VERSION for AMD GPUs not yet in ROCm's default target list (e.g. '11.0.0' for RDNA3).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(lib.attrByPath [ "services" "subgen" "enable" ] false config);
        message = "services.subgen-container and services.subgen (subtitle-stack) cannot both be enabled — they define conflicting Subgen containers.";
      }
      {
        assertion = !(cfg.transcribeOrTranslate == "translate" && lib.hasSuffix "turbo" cfg.whisperModel);
        message = "large-v3-turbo does not support translation — use large-v3 or another model when transcribeOrTranslate is 'translate'.";
      }
    ];

    virtualisation.quadlet.containers.subgen-standalone = {
      autoStart = true;
      containerConfig = {
        image =
          if cfg.image != null then
            cfg.image
          else if cfg.gpu.enable then
            "mccloud/subgen:amd"
          else
            "mccloud/subgen:cpu";
        publishPorts = [
          "${toString cfg.port}:9000"
        ];
        volumes = [
          "${cfg.mediaDir}/tv:/data/media/tv"
          "${cfg.mediaDir}/movies:/data/media/movies"
          "${cfg.modelDir}:/subgen/models"
        ];
        environments = {
          WHISPER_MODEL = cfg.whisperModel;
          WHISPER_THREADS = toString cfg.whisperThreads;
          CONCURRENT_TRANSCRIPTIONS = toString cfg.concurrentTranscriptions;
          TRANSCRIBE_OR_TRANSLATE = cfg.transcribeOrTranslate;
          SUBTITLE_LANGUAGE_NAME = cfg.subtitleLanguageName;
          PREFERRED_AUDIO_LANGUAGES = cfg.preferredAudioLanguages;
          WEBHOOKPORT = "9000";
          TRANSCRIBE_DEVICE = if cfg.gpu.enable then "cuda" else "cpu";
          CLEAR_VRAM_ON_COMPLETE = "True";
          MODEL_PATH = "./models";
          DEBUG = "True";
        }
        // lib.optionalAttrs (cfg.forceDetectedLanguageTo != "") {
          FORCE_DETECTED_LANGUAGE_TO = cfg.forceDetectedLanguageTo;
        }
        // lib.optionalAttrs cfg.gpu.enable {
          CT2_CUDA_ALLOCATOR = "cub_caching";
        }
        // lib.optionalAttrs (cfg.gpu.enable && cfg.gpu.hsaOverrideGfxVersion != null) {
          HSA_OVERRIDE_GFX_VERSION = cfg.gpu.hsaOverrideGfxVersion;
        }
        // lib.optionalAttrs hasPlex {
          PLEXSERVER = cfg.plexServer;
        }
        // lib.optionalAttrs hasJellyfin {
          JELLYFINSERVER = cfg.jellyfinServer;
        }
        // cfg.extraEnvironments;
        inherit (cfg) environmentFiles;
        devices = lib.optionals cfg.gpu.enable [
          "/dev/dri"
          "/dev/kfd"
        ];
        addGroups = lib.optionals cfg.gpu.enable [
          "keep-groups"
        ];
        podmanArgs = [ "--tty" ];
        userns = "keep-id";
      };

      unitConfig =
        lib.mkIf
          ((cfg.environmentFiles != [ ]) && (lib.attrByPath [ "hm" "security" "sops" "enable" ] false config))
          {
            Requires = [ "sops-nix.service" ];
            After = [ "sops-nix.service" ];
          };
    };
  };
}
