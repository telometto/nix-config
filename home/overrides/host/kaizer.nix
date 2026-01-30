# Host-specific user overrides for kaizer
# These settings will be applied to all users on kaizer host
{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.variety ];

  hm = {
    programs = {
      media = {
        enable = true;

        mpv.enable = true;
        yt-dlp.enable = true;
        jf-mpv.enable = lib.mkForce false;
      };

      gaming.lutris.enable = lib.mkForce false;

      terminal.zellij.exitShellOnExit = true;
    };
  };

  programs.ssh.enableDefaultConfig = false;
}
