# User-specific configuration for luke on kaizer host
# This file is automatically imported only for luke user on kaizer
{
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = [ pkgs.variety ];

  hm = {
    programs = {
      media = {
        enable = true;

        mpv.enable = true;
        yt-dlp.enable = true;
        jf-mpv.enable = false;
      };
    };
  };
}
