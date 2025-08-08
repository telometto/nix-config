# Blizzard Server Home Manager configuration for admin user
{ config, lib, pkgs, VARS, inputs, ... }:

{
  imports = [
    ../../../../../shared/home.nix
    ../../../../../home/secrets.nix
    ../../../../../home/programs/server-programs.nix
    ../../../../../home/services/server-services.nix
  ];

  home = {
    username = VARS.users.admin.user;
    stateVersion = "24.11";

    enableDebugInfo = true;
    preferXdgDirectories = true;

    keyboard.layout = "no";
  };

  # Server-specific packages (minimal)
  home.packages = with pkgs; [ atuin sqlite ];
}
