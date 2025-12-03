{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.programs.media;
in
{
  options.hm.programs.media = {
    enable = lib.mkEnableOption "Media tools and applications";

    mpv.enable = lib.mkEnableOption "MPV media player";
    yt-dlp.enable = lib.mkEnableOption "yt-dlp downloader";
    jf-mpv.enable = lib.mkEnableOption "Jellyfin player";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional media packages to install";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.mpv = lib.mkIf cfg.mpv.enable {
      enable = lib.mkDefault true;
      # TODO: Declaratively configure mpv
    };

    programs.yt-dlp = lib.mkIf cfg.yt-dlp.enable {
      enable = lib.mkDefault true;
      # TODO: Declaratively configure yt-dlp
    };

    services.jellyfin-mpv-shim = lib.mkIf cfg.jf-mpv.enable {
      enable = lib.mkDefault true;
      # TODO: Declaratively configure
    };

    home.packages = [
      pkgs.jamesdsp
      pkgs.spotify
      pkgs.protonmail-desktop
      pkgs.plex-desktop
    ]
    ++ cfg.extraPackages;
  };
}
