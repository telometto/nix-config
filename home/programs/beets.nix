{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.programs.beets;
  directory = if cfg.musicDirectory != null then cfg.musicDirectory else config.xdg.userDirs.music;
  settings = config.programs.beets.settings;
  stateDirectory = "${config.xdg.stateHome}/beets";
  helper = import ../../lib/beets-import-package.nix {
    inherit pkgs;
    beetsPackage = config.programs.beets.package;
  };
  configuredHelper = pkgs.writeShellScriptBin "beets-import" ''
    exec ${helper}/bin/beets-import \
      --library-root ${lib.escapeShellArg settings.directory} \
      --database ${lib.escapeShellArg settings.library} \
      --state-directory ${lib.escapeShellArg stateDirectory} "$@"
  '';
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
        "musicbrainz"
        "chroma"
      ];
      description = "Beets plugins. The web plugin is added when webInterface.enable is true.";
    };
    guidedImport.enable = lib.mkEnableOption "the interactive, copy-only beets-import command";
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
      description = "Beets settings recursively overriding defaults. Guided imports enforce their own preservation settings.";
    };
  };
  config = lib.mkIf cfg.enable {
    programs.beets = {
      enable = lib.mkDefault true;
      settings = lib.recursiveUpdate (
        {
          plugins = lib.unique (cfg.plugins ++ lib.optional cfg.webInterface.enable "web");
          inherit directory;
          library = "${config.xdg.dataHome}/beets/library.db";
          statefile = "${stateDirectory}/state.pickle";
          original_date = false;
          per_disc_numbering = false;
          paths = {
            default = "Albums/$albumartist/$year/$album%if{$edition, [$edition]}/$track-$title";
            comp = "Albums/Various Artists/$year/$album%if{$edition, [$edition]}/$track-$title";
            singleton = "Unsorted/$artist/$title";
          };
          import = {
            copy = true;
            move = false;
            write = false;
            timid = true;
            quiet = false;
            none_rec_action = "ask";
            from_scratch = false;
            group_albums = true;
            duplicate_action = "ask";
            log = "${stateDirectory}/import.log";
          };
          convert.auto = false;
          scrub.auto = false;
          fetchart.auto = false;
          embedart.auto = false;
          lastgenre.auto = false;
          replaygain.auto = false;
          ui.color = true;
        }
        // lib.optionalAttrs cfg.webInterface.enable {
          web = { inherit (cfg.webInterface) host port; };
        }
      ) cfg.extraSettings;
    };
    home.packages = lib.optional cfg.guidedImport.enable configuredHelper;
    assertions = lib.optional cfg.guidedImport.enable {
      assertion = lib.all (path: builtins.isString path && lib.hasPrefix "/" path) [
        settings.directory
        settings.library
        stateDirectory
      ];
      message = "Guided beets imports require absolute library, database, and state paths.";
    };
  };
}
