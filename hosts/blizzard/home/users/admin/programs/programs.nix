{ config, lib, pkgs, VARS, ... }:

{
  programs = {
    beets = {
      enable = true;

      settings = {
        plugins = "fetchart embedart convert scrub replaygain lastgenre chroma web inline";

        directory = config.xdg.userDirs.music;
        # library = "${config.home.homeDirectory}/.config/beets/musiclibrary.blb";

        art_filename = "albumart";
        threaded = true;
        original_date = false;
        per_disc_numbering = false;

        convert = {
          auto = true;
          ffmpeg = "${pkgs.ffmpeg.out}/bin/ffmpeg";
          opts = "-ab 320k -ac 2 -ar 48000";
          max_bitrate = 320;
          threads = 6;
        };

        item_fields = {
          disk_folder = ''
          return f"Disk-{disc}" if disctotal > 1 else ""
          '';
        };

        paths = {
          default = "\"Albums/$albumartist/$year/$album%aunique{}/$disk_folder/$track - $title\"";
          singleton = "\"Non-Albums/$artist/$title\"";
          comp = "\"Compilations/$album%aunique{}/$disk_folder/$track - $title\"";
          albumtype_soundtrack = "\"Soundtracks/$album%aunique{}/$disk_folder/$track - $title\"";
        };

        import = {
          write = true;
          copy = false;
          move = true;
          resume = false;
          incremental = true;
          quiet = true;
          quiet_fallback = "skip";
          timid = false;
          duplicate_action = "skip";
          # log = "";
          languages = "en";
        };

        ui = { color = true; };

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

        web = {
          host = "0.0.0.0";
          port = 8337;
        };
      };
    };

    keychain = {
      keys = [ "borg-blizzard" "sops-hm-blizzard" "zeno-blizzard" ];
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
