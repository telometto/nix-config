# Host-specific user overrides for kaizer
# These settings will be applied to all users on kaizer host
{ lib, ... }:
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
    };
  };

  programs.ssh.enableDefaultConfig = false;
}
