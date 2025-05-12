{ config, lib, pkgs, VARS, ... }:

{
  home = {
    file.".ssh/config".text = ''
      Host *
        ForwardAgent yes
        AddKeysToAgent yes
        Compression yes

      Host github.com
        Hostname ssh.github.com
        Port 443
        User git
        IdentityFile ${config.home.homeDirectory}/.ssh/zeno-blizzard
    '';
  };

  programs = {
    beets = {
      enable = true;

      settings = {
        plugins =
          "fetchart embedart convert scrub replaygain lastgenre chroma web inline";

        directory = config.xdg.userDirs.music;
        # library = "${config.home.homeDirectory}/.config/beets/musiclibrary.blb";
        statefile = "${config.home.homeDirectory}/.config/beets/state.pickle";

        art_filename = "albumart";
        threaded = true;
        original_date = false;
        per_disc_numbering =
          true; # Starts numbering from 1 again for each disk set

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

        item_fields.disk_folder =
          ''return f"Disk-{disc}" if disctotal > 1 else ""'';

        paths = {
          default =
            "Albums/$albumartist/$year/$album%aunique{}/$disk_folder/$track - $title";
          singleton = "Non-Albums/$artist/$title";
          comp = "Compilations/$album%aunique{}/$disk_folder/$track - $title";
          albumtype_soundtrack =
            "Soundtracks/$album%aunique{}/$disk_folder/$track - $title";
        };

        import = {
          # Common options
          write = true;
          copy = false;
          move = true;
          timid = false;
          quiet = true;
          log = "${config.home.homeDirectory}/.config/beets/beets.log";

          # Other options
          default_action = "apply";
          languages = "en";
          quiet_fallback = "skip";
          none_rec_action = "ask";

          # Rare options
          # link = false;
          # hardlink = false;
          # reflink = false;
          # delete = false;
          resume = false;
          incremental = false;
          incremental_skip_later = false;
          from_scratch = true;
          autotag = true;
          # singletons = false;
          # detail = false;
          # flat = false;
          # group_albums = false;
          # pretend = false;
          # search_ids = [ ];
          # duplicate_keys = {
          #   album = "albumartist album";
          #   item = "artist title";
          # };
          duplicate_action = "skip";
          # duplicate_verbose_prompt = false;
          # bell = false;
          # set_fields = ;
          # ignored_alias_types = ;
          # singleton_album_disambig = true;
        };

        ui = { color = true; };

        lastgenre = {
          auto = true;
          source = "album";
        };

        embedart = { auto = true; };

        fetchart = { auto = true; };

        replaygain = { auto = false; };

        scrub = { auto = true; };

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

        web = {
          host = "0.0.0.0";
          port = 8337;
        };
      };
    };

    fastfetch = {
      settings = {
        modules = [
          "title"
          "separator"
          "os"
          "kernel"
          "initsystem"
          "uptime"
          "loadavg"
          "processes"
          "packages"
          "shell"
          "editor"
          "display"
          "de"
          "terminal"
          {
            "type" = "cpu";
            "showPeCoreCount" = true;
            "temp" = true;
          }
          "cpuusage"
          {
            "type" = "gpu";
            "driverSpecific" = true;
            "temp" = true;
          }
          "memory"
          "swap"
          {
            "type" = "disk";
            "folders" = "/";
            "key" = "root";
          }
          {
            "type" = "zpool";
            "folders" = "/flash";
            "key" = "flash";
          }
          {
            "type" = "zpool";
            "folders" = "/rpool";
            "key" = "rpool";
          }
          { "type" = "localip"; }
          {
            "type" = "weather";
            "timeout" = 1000;
          }
          "break"
        ];
      };
    };

    keychain = {
      enable = false;

      enableBashIntegration = true;
      enableZshIntegration = true;

      keys = [
        "borg-blizzard"
        "sops-hm-blizzard"
        "zeno-blizzard"
      ];
    };

    zsh = {
      shellAliases = {
        # Kubernetes
        k = "kubectl";
        kap = "kubectl apply -f";
        kdl = "kubectl delete";
        kgt = "kubectl get";
        kex = "kubectl exec -it";
        klo = "kubectl logs";
        kev = "kubectl events";
        kds = "kubectl describe";
      };
    };
  };
}
