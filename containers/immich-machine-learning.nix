# Standalone Immich machine-learning container.
# Home Manager module - runs rootless via quadlet-nix.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.immich-machine-learning-container;

  imageSuffix = lib.optionalString (cfg.acceleration != "cpu") "-${cfg.acceleration}";
  defaultImage = "ghcr.io/immich-app/immich-machine-learning:v${pkgs.immich.version}${imageSuffix}";
in
{
  options.services.immich-machine-learning-container = {
    enable = lib.mkEnableOption "Standalone Immich machine-learning container";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3003;
      description = "Host port to expose the Immich machine-learning API on.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host address to bind the published port to.";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/immich-machine-learning/cache";
      description = "Path for persistent Immich machine-learning model cache.";
    };

    image = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Container image to use. Defaults to the current nixpkgs Immich version with the selected acceleration suffix.";
    };

    acceleration = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "cuda"
      ];
      default = "cuda";
      description = "Machine-learning image acceleration backend.";
    };

    cudaDevice = lib.mkOption {
      type = lib.types.str;
      default = "nvidia.com/gpu=all";
      description = "NVIDIA CDI device selector passed to Podman when CUDA acceleration is enabled.";
    };

    modelTtl = lib.mkOption {
      type = lib.types.str;
      default = "600";
      description = "Seconds of inactivity before machine-learning models are unloaded.";
    };

    extraEnvironments = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for the Immich machine-learning container.";
    };

    extraPodmanArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional arguments passed to podman run.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.tmpfiles.rules = [
      "d ${cfg.cacheDir} 0755 - - -"
    ];

    virtualisation.quadlet.containers.immich-machine-learning = {
      autoStart = true;
      containerConfig = {
        image = if cfg.image != null then cfg.image else defaultImage;
        publishPorts = [
          "${cfg.listenAddress}:${toString cfg.port}:3003"
        ];
        volumes = [
          "${cfg.cacheDir}:/cache:U"
        ];
        environments = {
          IMMICH_HOST = "0.0.0.0";
          IMMICH_PORT = "3003";
          MACHINE_LEARNING_CACHE_FOLDER = "/cache";
          MACHINE_LEARNING_MODEL_TTL = cfg.modelTtl;
          HF_HOME = "/cache/huggingface";
          HF_HUB_CACHE = "/cache/huggingface/hub";
          HF_XET_CACHE = "/cache/huggingface/xet";
          HF_HUB_DISABLE_XET = "1";
          XDG_CACHE_HOME = "/cache/xdg";
          HOME = "/cache/home";
        }
        // lib.optionalAttrs (cfg.acceleration == "cuda") {
          NVIDIA_VISIBLE_DEVICES = "all";
          NVIDIA_DRIVER_CAPABILITIES = "compute,utility";
        }
        // cfg.extraEnvironments;
        devices = lib.optionals (cfg.acceleration == "cuda") [
          cfg.cudaDevice
        ];
        addGroups = lib.optionals (cfg.acceleration == "cuda") [
          "keep-groups"
        ];
        podmanArgs = cfg.extraPodmanArgs;
      };
    };
  };
}
