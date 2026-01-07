{ lib, config, ... }:
let
  cfg = config.sys.home;
in
{
  options.sys.home = {
    enable = lib.mkEnableOption "Home-manager integration across all sys hosts";

    template = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Base Home Manager configuration applied to every managed user.
        Extend or override this to tweak the shared template.
      '';
    };

    extraModules = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
      description = ''
        Additional Home Manager modules to import for every generated user profile.
      '';
    };

    users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (_: {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable Home Manager configuration for this user";
            };

            extraConfig = lib.mkOption {
              type = lib.types.attrs;
              default = { };
              description = "Per-user overrides merged on top of the shared template.";
            };

            extraModules = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
              description = "Additional modules to import for this specific user.";
            };
          };
        })
      );
      default = { };
      description = "Per-user overrides for generated Home Manager configurations.";
    };
  };

  options.home.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Deprecated. Use sys.home.enable instead.";
  };

  config.home.enable = lib.mkIf cfg.enable (lib.mkDefault true);
}
