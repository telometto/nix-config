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
      background-opacity = 0.950000;

      cursor-style = "bar";
      cursor-style-blink = true;

      font-family = "FiraCode Nerd Font Mono";
      font-size = 13;

      mouse-hide-while-typing = true;

      notify-on-command-finish = "unfocused";
      notify-on-command-finish-action = "no-bell,notify";

      shell-integration-features = "sudo,ssh-env";

      theme = "Pale Night Hc";

      window-height = 27;
      window-padding-balance = true;
      window-padding-x = 8;
      window-padding-y = 4;
      window-width = 90;
    };
  };
}
