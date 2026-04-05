# Standalone Ollama container — can run on any host independently
# Home Manager module — runs rootless via quadlet-nix
{ lib, config, ... }:
let
  cfg = config.services.ollama-container;
in
{
  options.services.ollama-container = {
    enable = lib.mkEnableOption "Standalone Ollama container";

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Host port to expose the Ollama API on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/docker/ollama";
      description = "Path for persistent Ollama model storage.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ollama/ollama:latest";
      description = "Container image to use.";
    };

    extraEnvironments = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for the Ollama container.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 - - -"
    ];

    virtualisation.quadlet.containers.ollama = {
      autoStart = true;
      containerConfig = {
        image = cfg.image;
        publishPorts = [
          "${toString cfg.port}:11434"
        ];
        volumes = [
          "${cfg.dataDir}:/root/.ollama"
        ];
        environments = {
          OLLAMA_HOST = "0.0.0.0";
        }
        // cfg.extraEnvironments;
        userns = "keep-id";
      };
    };
  };
}
