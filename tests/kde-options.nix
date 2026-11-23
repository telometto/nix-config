# Public-only evaluation; no runtime files are read or activated:
# nix eval --offline --impure --json --expr '
#   let
#     lock = builtins.fromJSON (builtins.readFile ./flake.lock);
#     source = name:
#       builtins.fetchTree lock.nodes.${lock.nodes.${lock.root}.inputs.${name}}.locked;
#   in (import ./tests/kde-options.nix {
#     pkgs = import (source "nixpkgs") { system = "x86_64-linux"; };
#     hmStable = source "hm-stable";
#   }).cases'
{ pkgs, hmStable }:
let
  inherit (pkgs) lib;
  hm = import "${hmStable}/lib" { inherit lib; };
  make =
    kde: extra:
    hm.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ../home/desktop/kde.nix
        {
          home = {
            username = "kde-options-fixture";
            homeDirectory = "/tmp/kde-options-fixture";
            stateVersion = "26.05";
          };
          programs.ssh.enableDefaultConfig = false;
          hm.desktop.kde = kde;
        }
        extra
      ];
    };
  accepts =
    evaluation:
    let
      result = builtins.tryEval evaluation.config.home.username;
    in
    result.success && result.value == "kde-options-fixture";
  rejects = kde: !(builtins.tryEval (make kde { }).config.home.username).success;
  enabled = make { enable = true; } { };
  disabled = make { } { };
  additional =
    make
      {
        enable = true;
        extraPackages = [ pkgs.hello ];
      }
      {
        home.sessionVariables.KDE_OPTIONS_FIXTURE = "native";
        xdg.configFile."kde-options-fixture".text = "Native Home Manager setting";
      };
  disabledAdditional = make { extraPackages = [ pkgs.hello ]; } { };
  has =
    name: evaluation: lib.any (package: lib.getName package == name) evaluation.config.home.packages;
  # Inspect the actual module's assertion text before Home Manager turns failed
  # assertions into an exception. The cases below also exercise that exception
  # through the real Home Manager entry point.
  removalAssertions =
    (lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        ../home/desktop/kde.nix
        {
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
          };
          config = {
            _module.check = false;
            hm.desktop.kde.extraConfig = {
              fixture = true;
            };
          };
        }
      ];
    }).config.assertions;
  cases = {
    enabledWithoutLegacyOptionEvaluates = accepts enabled;
    disabledWithoutLegacyOptionEvaluates = accepts disabled;
    extraPackagesStillAdd = has "kate" additional && has "hello" additional;
    disabledAddsNoKdeOrExtraPackages =
      !(has "kate" disabledAdditional) && !(has "hello" disabledAdditional);
    nativeSettingsWork =
      accepts additional
      && additional.config.home.sessionVariables.KDE_OPTIONS_FIXTURE == "native"
      && additional.config.xdg.configFile."kde-options-fixture".text == "Native Home Manager setting";
    enabledLegacySettingsRejected = rejects {
      enable = true;
      extraConfig = {
        fixture = true;
      };
    };
    enabledEmptyLegacySettingsRejected = rejects {
      enable = true;
      extraConfig = { };
    };
    disabledLegacySettingsRejected = rejects {
      enable = false;
      extraConfig = {
        fixture = true;
      };
    };
    disabledEmptyLegacySettingsRejected = rejects {
      enable = false;
      extraConfig = { };
    };
    migrationExplainsNativeReplacement = lib.any (
      entry:
      !entry.assertion
      && lib.hasInfix "hm.desktop.kde.extraConfig" entry.message
      && lib.hasInfix "native Home Manager options" entry.message
      && lib.hasInfix "never applied its settings" entry.message
    ) removalAssertions;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) cases);
in
assert lib.assertMsg (
  failures == [ ]
) "KDE-option contracts failed: ${lib.concatStringsSep ", " failures}";
pkgs.runCommand "kde-option-tests" { passthru = { inherit cases; }; } ''
  touch "$out"
''
