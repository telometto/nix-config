# Host-specific user overrides for kaizer
# These settings will be applied to all users on kaizer host
{ lib, pkgs, ... }:
{
  home.packages = [
    pkgs.variety
    pkgs.rustdesk-flutter
    pkgs.polychromatic # Razer configuration tool
    pkgs.kdePackages.krdc
    pkgs.meld
    pkgs.rendercv
  ];

  hm = {
    langs = "it_IT.UTF-8";

    programs = {
      media = {
        enable = true;

        mpv.enable = true;
        yt-dlp.enable = true;
        jf-mpv.enable = lib.mkForce false;
      };

      gaming.lutris.enable = lib.mkForce false;

      terminal.zellij.exitShellOnExit = false;
    };
  };

  programs = {
    ssh.enableDefaultConfig = false;
    atuin.enable = lib.mkForce false;
  };
}
