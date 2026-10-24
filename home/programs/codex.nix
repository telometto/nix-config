{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.hm.programs.codex;
in
{
  # The stable HM module lacks mutable settings, profiles, hooks, and plugins.
  disabledModules = [ "programs/codex.nix" ];
  imports = [
    (
      {
        lib,
        config,
        pkgs,
        ...
      }:
      import "${inputs.hm-master}/modules/programs/codex" {
        inherit pkgs;
        # Supply the two master-only helpers to Codex without changing the
        # library used by the other stable Home Manager modules.
        lib = lib.extend (
          _: prev: {
            hm = prev.hm // {
              generators = prev.hm.generators // {
                inherit (import "${inputs.hm-master}/modules/lib/generators.nix" { lib = prev; })
                  mkImpureConfigMerger
                  mkImpureConfigCleanup
                  ;
              };
            };
          }
        );

        # Keep Codex's directory preference independent of other programs.
        config = config // {
          home = config.home // {
            inherit (cfg) preferXdgDirectories;
          };
        };
      }
    )
  ]
  ++
    map (name: lib.mkAliasOptionModule [ "hm" "programs" "codex" name ] [ "programs" "codex" name ])
      [
        "package"
        "enableMcpIntegration"
        "mutableSettings"
        "settings"
        "profiles"
        "context"
        "contextOverride"
        "hooks"
        "plugins"
        "marketplaces"
        "skills"
        "rules"
      ];

  options.hm.programs.codex = {
    enable = lib.mkEnableOption "Declarative Codex configuration";

    preferXdgDirectories = lib.mkOption {
      type = lib.types.bool;
      default = config.home.preferXdgDirectories;
      defaultText = lib.literalExpression "config.home.preferXdgDirectories";
      description = ''
        Use the XDG config directory for Codex. Disable to keep an existing
        ~/.codex installation, including its authentication and session state.
        This does not change the directory preference of other programs.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.codex.enable = lib.mkDefault true;
  };
}
