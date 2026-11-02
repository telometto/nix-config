{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hm.services.autotidy;
  yamlFormat = pkgs.formats.yaml { };
  configFile = yamlFormat.generate "autotidy-config.yaml" cfg.settings;
in
{
  imports = [ inputs.autotidy.homeModules.default ];

  options.hm.services.autotidy = {
    enable = lib.mkEnableOption "autotidy file organization";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.autotidy.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "inputs.autotidy.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "The autotidy package to use.";
    };

    settings = lib.mkOption {
      inherit (yamlFormat) type;
      default = {
        rules = [ ];
      };
      description = ''
        Configuration written to ~/.config/autotidy/config.yaml.
        No files are organized until rules are added.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.autotidy = {
      enable = lib.mkDefault true;
      inherit (cfg) package;
    };

    # Upstream uses ~/.config directly, regardless of XDG_CONFIG_HOME.
    home.file.".config/autotidy/config.yaml".source = configFile;

    systemd.user.services.autotidy.Unit.X-Restart-Triggers = [ "${configFile}" ];
  };
}
