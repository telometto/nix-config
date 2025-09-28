{ lib, config, pkgs, ... }:
let cfg = config.hm.programs.media;
in {
  options.hm.programs.media = {
    enable = lib.mkEnableOption "Media tools and applications";

    mpv.enable = lib.mkEnableOption "MPV media player";
    yt-dlp.enable = lib.mkEnableOption "yt-dlp downloader";
  };

  config = lib.mkIf cfg.enable {
    programs.mpv = lib.mkIf cfg.mpv.enable {
      enable = true;
      # TODO: Declaratively configure mpv
    };

    programs.yt-dlp = lib.mkIf cfg.yt-dlp.enable {
      enable = true;
      # TODO: Declaratively configure yt-dlp
    };

    home.packages = [
      # Media utilities
      pkgs.jamesdsp
      pkgs.spotify
      # pkgs.discord # no hm options; replaced by vesktop
      # pkgs.element-desktop # has hm options; should be replaced
      # pkgs.thunderbird # has hm options; should be replaced
      pkgs.protonmail-desktop
      pkgs.plex-desktop
    ];
  };
}
