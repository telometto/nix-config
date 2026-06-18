# Role-wide HM overrides for desktop-role hosts (applies to every HM user when sys.role.desktop.enable = true)
{
  lib,
  config,
  pkgs,
  ...
}:
{
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
