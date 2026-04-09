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
      description = "Whisper model to use (tiny, base, small, medium, large-v3, large-v3-turbo, etc.).";
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
    virtualisation.quadlet.containers.subgen = {
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
          WEBHOOKPORT = "9000";
          TRANSCRIBE_DEVICE = if cfg.gpu.enable then "cuda" else "cpu";
          CLEAR_VRAM_ON_COMPLETE = "True";
          MODEL_PATH = "./models";
          DEBUG = "True";
        }
        // lib.optionalAttrs (cfg.gpu.enable) {
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
        devices = lib.optionals cfg.gpu.enable [
          "/dev/dri"
          "/dev/kfd"
        ];
        addGroups = lib.optionals cfg.gpu.enable [
          "video"
          "render"
        ];
        podmanArgs = [ "--tty" ];
        userns = "keep-id";
      };
    };
  };
}
