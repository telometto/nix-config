{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.programs.beets;
in
{
  options.hm.programs.beets = {
    enable = lib.mkEnableOption "Beets music library manager";

    musicDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Music directory path. If null, uses XDG music directory.";
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "fetchart"
        "embedart"
        "convert"
        "scrub"
        "replaygain"
        "lastgenre"
        "chroma"
        "inline"
      ];
      description = ''
        List of Beets plugins to enable.
        The 'web' plugin is automatically added when webInterface.enable is true.
      '';
      example = [
        "fetchart"
        "embedart"
        "lastfm"
        "lyrics"
      ];
    };

    webInterface = {
      enable = lib.mkEnableOption "Beets web interface";
      host = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Web interface host address";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8337;
        description = "Web interface port";
      };
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Beets settings merged with defaults";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.beets = {
      enable = lib.mkDefault true;

      settings = lib.mkMerge [
        {
          plugins =
            let
              userPlugins = cfg.plugins;
              webPlugin = lib.optional cfg.webInterface.enable "web";
              allPlugins = userPlugins ++ webPlugin;
            in
            lib.concatStringsSep " " allPlugins;

          directory = if cfg.musicDirectory != null then cfg.musicDirectory else config.xdg.userDirs.music;
          library = "${config.home.homeDirectory}/.config/beets/library.db";
          statefile = "${config.home.homeDirectory}/.config/beets/state.pickle";

          art_filename = "albumart";
          threaded = true;
          original_date = false;
          per_disc_numbering = true; # Starts numbering from 1 again for each disk set

          convert = {
            auto = true;
            ffmpeg = "${pkgs.ffmpeg.out}/bin/ffmpeg";
            opts = "-ab 320k -ac 2 -ar 48000";
            max_bitrate = 320;
            threads = 6;
          };

          match = {
            strong_rec_thresh = 0.04;
            medium_rec_thresh = 0.25;
            rec_gap_thresh = 0.25;
            distance_weights = {
              source = 2.0;
              artist = 3.0;
              album = 3.0;
              media = 1.0;
              mediums = 1.0;
              year = 1.0;
              country = 0.5;
              label = 0.5;
              catalognum = 0.5;
              albumdisambig = 0.5;
              album_id = 5.0;
              tracks = 2.0;
              missing_tracks = 0.9;
              unmatched_tracks = 0.6;
              track_title = 3.0;
              track_artist = 2.0;
              track_index = 1.0;
              track_length = 2.0;
              track_id = 5.0;
            };

            preferred = {
              countries = [ ];
              media = [ ];
              original_year = true;
            };
          };

          item_fields = {
            disk_folder = ''return f"Disk-{disc}" if disctotal > 1 else ""'';
          };

          paths = {
            default = "Albums/$albumartist/$year/$album%aunique{}/$disk_folder/$track - $title";
            singleton = "Non-Albums/$artist/$title";
            comp = "Compilations/$album%aunique{}/$disk_folder/$track - $title";
            albumtype_soundtrack = "Soundtracks/$album%aunique{}/$disk_folder/$track - $title";
          };

          import = {
            write = true;
            copy = false;
            move = true;
            timid = false;
            quiet = true;
            log = "${config.home.homeDirectory}/.config/beets/beets.log";

            default_action = "apply";
            languages = "en";
            quiet_fallback = "skip";
            none_rec_action = "ask";

            resume = false;
            incremental = false;
            incremental_skip_later = false;
            from_scratch = true;
            autotag = true;
            duplicate_action = "skip";
          };

          ui = {
            color = true;
          };

          lastgenre = {
            auto = true;
            source = "album";
          };

          embedart = {
            auto = true;
          };

          fetchart = {
            auto = true;
          };

          replaygain = {
            auto = false;
          };

          scrub = {
            auto = true;
          };

          replace = {
            "^\\." = "_";
            "[\\x00-\\x1f]" = "_";
            "[<>:\"\\?\\*\\|]" = "_";
            "[\\xE8-\\xEB]" = "e";
            "[\\xEC-\\xEF]" = "i";
            "[\\xE2-\\xE6]" = "a";
            "[\\xF2-\\xF6]" = "o";
            "[\\xF8]" = "o";
            "\\.$" = "_";
            "\\s+$" = "";
          };
        }
        (lib.optionalAttrs cfg.webInterface.enable {
          web = {
            inherit (cfg.webInterface) host port;
          };
        })
        cfg.extraSettings
      ];
    };
  };
}
