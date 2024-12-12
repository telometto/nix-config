{ config, lib, pkgs, VARS, ... }:

{
  imports = [
    # Programs
    ./programs/defaults.nix

    # Security
    # ./security/secrets/sops-home.nix # Imported on a per-user basis

    # Services
    ./services/gpg/agent.nix
    ./services/ssh/agent.nix

    # XDG
    ./xdg/defaults.nix
  ];
}
