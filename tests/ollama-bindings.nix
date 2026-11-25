{ pkgs }:
let
  inherit (pkgs) lib;
  evaluate =
    settings:
    (lib.evalModules {
      modules = [
        ../containers/ollama.nix
        {
          # The contract under test is the container module's port publication.
          options.systemd = lib.mkOption { type = lib.types.attrs; };
          options.virtualisation = lib.mkOption { type = lib.types.attrs; };
          config.services.ollama-container = {
            enable = true;
          }
          // settings;
        }
      ];
    }).config.virtualisation.quadlet.containers.ollama-standalone.containerConfig;
  defaults = evaluate { };
  explicit = evaluate {
    port = 12000;
    listenAddresses = [
      "127.0.0.1"
      "100.67.190.43"
      "::1"
    ];
  };
in
assert defaults.publishPorts == [ "127.0.0.1:11434:11434" ];
assert
  explicit.publishPorts == [
    "127.0.0.1:12000:11434"
    "100.67.190.43:12000:11434"
    "[::1]:12000:11434"
  ];
pkgs.runCommand "ollama-bindings" { } ''
  touch "$out"
''
