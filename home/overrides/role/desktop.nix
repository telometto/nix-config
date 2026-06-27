# Role-wide HM overrides for desktop-role hosts (applies to every HM user when sys.role.desktop.enable = true)
{
  lib,
  config,
  pkgs,
  ...
}:
let
  mkRoleDefault = lib.mkOverride 900;
in
{
  imports = [ ./ssh-common.nix ];

  home.packages = [
    pkgs.variety
  ];

  hm.programs = {
    browsers.chromium.enable = mkRoleDefault false;
    media.jf-mpv.enable = mkRoleDefault false;
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

      window-width = 100;
      window-height = 80;

      window-padding-x = 8;
      window-padding-y = 4;
      window-padding-balance = true;

      mouse-hide-while-typing = true;

      scrollback-limit = 100000000;

      clipboard-paste-bracketed-safe = false;

      notify-on-command-finish = "unfocused";
      notify-on-command-finish-action = "no-bell,notify";
      notify-on-command-finish-after = "30s";

      quick-terminal-position = "top";
      quick-terminal-size = "40%";
      quick-terminal-autohide = false;

      shell-integration = "zsh";
      shell-integration-features = "sudo,ssh-env";

      keybind = [
        "ctrl+alt+space=toggle_quick_terminal"
      ];

      command-palette-entry = [
        "title:\"Toggle Quick Terminal\",description:\"Show or hide the quick terminal.\",action:toggle_quick_terminal"
      ];
    };
  };
}
