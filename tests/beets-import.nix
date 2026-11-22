# Public-only check. No secrets, activation, user configuration, or collection.
# nix build --impure --no-link --expr 'import ./tests/beets-import.nix {
#   nixpkgs = /path/to/locked/nixpkgs; hmStable = /path/to/locked/home-manager;
# }'
{
  nixpkgs,
  hmStable,
  system ? builtins.currentSystem,
}:
let
  pkgs = import nixpkgs { inherit system; };
  inherit (pkgs) lib;
  hm = import "${hmStable}/lib" { inherit lib; };
  homeDirectory = "/tmp/beets-module-fixture";
  make =
    settings:
    (hm.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ../home/programs/beets.nix
        {
          home = {
            username = "beets-fixture";
            inherit homeDirectory;
            stateVersion = "26.05";
          };
          xdg.userDirs.music = "${homeDirectory}/Music";
          hm.programs.beets = settings;
        }
      ];
    }).config;
  enabled = make {
    enable = true;
    musicDirectory = "/rpool/unenc/media/data/music";
    guidedImport.enable = true;
  };
  disabled = make { };
  basic = make { enable = true; };
  custom = make {
    enable = true;
    extraSettings.import.timid = false;
    extraSettings.ui.color = false;
  };
  settings = enabled.programs.beets.settings;
  hasHelper = cfg: lib.any (package: lib.getName package == "beets-import") cfg.home.packages;
  cases = {
    root = settings.directory == "/rpool/unenc/media/data/music";
    providers = lib.all (name: lib.elem name settings.plugins) [
      "musicbrainz"
      "chroma"
    ];
    interactive =
      settings.import.timid && !settings.import.quiet && settings.import.none_rec_action == "ask";
    preserve =
      settings.import.copy
      && !settings.import.move
      && !settings.import.write
      && !settings.import.from_scratch;
    grouping = settings.import.group_albums;
    matching = !(settings ? match);
    noAutomaticChanges =
      !settings.convert.auto
      && !settings.scrub.auto
      && !settings.fetchart.auto
      && !settings.embedart.auto
      && !settings.lastgenre.auto;
    releaseDate = !settings.original_date && !settings.per_disc_numbering;
    paths =
      settings.paths.singleton == "Unsorted/$artist/$title"
      &&
        settings.paths.comp == "Albums/Various Artists/$year/$album%if{$edition, [$edition]}/$track-$title"
      &&
        settings.paths.default == "Albums/$albumartist/$year/$album%if{$edition, [$edition]}/$track-$title";
    xdg =
      settings.library == "${homeDirectory}/.local/share/beets/library.db"
      && settings.statefile == "${homeDirectory}/.local/state/beets/state.pickle"
      && settings.import.log == "${homeDirectory}/.local/state/beets/import.log";
    helper = hasHelper enabled && !(hasHelper basic);
    disabled =
      !disabled.programs.beets.enable
      && !(hasHelper disabled)
      && !(disabled.xdg.configFile ? "beets/config.yaml");
    overrides =
      !custom.programs.beets.settings.import.timid && !custom.programs.beets.settings.ui.color;
    fallback = basic.programs.beets.settings.directory == "${homeDirectory}/Music";
    assertions = lib.all (entry: entry.assertion) enabled.assertions;
  };
  package = import ../lib/beets-import-package.nix { inherit pkgs; };
in
assert lib.all (value: value) (builtins.attrValues cases);
pkgs.runCommand "beets-import-check"
  {
    nativeBuildInputs = [
      package.pythonEnv
      pkgs.ffmpeg
      pkgs.coreutils
    ];
    passthru = { inherit cases package; };
  }
  ''
    mkdir -p work/home/programs work/tests "$TMPDIR/xdg/config" "$TMPDIR/xdg/data" "$TMPDIR/xdg/state" "$TMPDIR/xdg/cache"
    cp -R ${../home/programs/beets-import} work/home/programs/beets-import
    cp ${./beets_import_test.py} work/tests/beets_import_test.py
    cp ${./beets_bulk_test.py} work/tests/beets_bulk_test.py
    cp ${./beets_workflow_test.py} work/tests/beets_workflow_test.py
    cp ${./beets_singleton_test.py} work/tests/beets_singleton_test.py
    chmod -R u+w work
    export XDG_CONFIG_HOME="$TMPDIR/xdg/config"
    export XDG_DATA_HOME="$TMPDIR/xdg/data"
    export XDG_STATE_HOME="$TMPDIR/xdg/state"
    export XDG_CACHE_HOME="$TMPDIR/xdg/cache"
    export BEETS_IMPORT_PACKAGE=${package}/bin/beets-import
    cd work
    python3 -B -m unittest discover -s tests -p 'beets*_test.py' -v
    mkdir -p "$out"
    cp ${pkgs.writeText "beets-module-cases.json" (builtins.toJSON cases)} "$out/cases.json"
  ''
