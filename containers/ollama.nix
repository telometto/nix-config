# Standalone Ollama container - can run on any host independently
# Home Manager module - runs rootless via quadlet-nix
{ lib, config, ... }:
let
  cfg = config.services.ollama-container;
  imagePins = import ../lib/oci-images.nix;
in
{
  options.services.ollama-container = {
    enable = lib.mkEnableOption "Standalone Ollama container";

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Host port to expose the Ollama API on.";
    };

    listenAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" ];
      description = "Host IP addresses on which to publish the Ollama API. Defaults to loopback; add explicit trusted-interface addresses for remote access.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/docker/ollama";
      description = "Path for persistent Ollama model storage.";
    };

    image = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Container image to use. Defaults to docker.io/ollama/ollama:rocm when gpu.enable is true, docker.io/ollama/ollama:latest otherwise.";
    };

    extraEnvironments = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for the Ollama container.";
    };

    gpu = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Pass through AMD GPU (/dev/dri, /dev/kfd) for hardware acceleration.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 - - -"
    ];

    virtualisation.quadlet.containers.ollama-standalone = {
      autoStart = true;
      containerConfig = {
        image =
          if cfg.image != null then
            cfg.image
          else if cfg.gpu.enable then
            imagePins.ollama.rocm
          else
            imagePins.ollama.cpu;
        # Keep exact-address listeners alive before Tailscale assigns its IP.
        # Freebind never falls back to publishing on a wildcard address.
        networks = [ "pasta:--freebind" ];
        publishPorts = map (
          address:
          let
            host = if lib.hasInfix ":" address then "[${address}]" else address;
          in
          "${host}:${toString cfg.port}:11434"
        ) cfg.listenAddresses;
        volumes = [
          "${cfg.dataDir}:/home/ollama/.ollama"
        ];
        environments = {
          OLLAMA_HOST = "0.0.0.0";
          OLLAMA_MODELS = "/home/ollama/.ollama/models";
          HOME = "/home/ollama";
        }
        // cfg.extraEnvironments;
        devices = lib.optionals cfg.gpu.enable [
          "/dev/dri"
          "/dev/kfd"
        ];
        addGroups = lib.optionals cfg.gpu.enable [
          "keep-groups"
        ];
        userns = "keep-id";
      };
    };
  };
}
