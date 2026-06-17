# Host-specific user overrides for snowfall
{
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [ ./ssh-common.nix ];

  # Snowfall-specific user configuration
  # These settings will be applied to all users on this host
  hm = {
    programs = {
      browsers.chromium.enable = lib.mkForce false;

      gaming.lutris.enable = true;
    };
  };

  programs.ghostty = {
    enable = true;

    enableZshIntegration = true;

    systemd.enable = true;

    settings = {
      font-family = "FiraCode Nerd Font Mono";
      font-size = 13;

      theme = "Pale Night Hc";

      background-opacity = 0.95;

      cursor-style = "block";
      cursor-style-blink = false;

      window-padding-x = 8;
      window-padding-y = 4;
      window-padding-balance = true;

      mouse-hide-while-typing = true;

      shell-integration = "zsh";
    };
  };
}
