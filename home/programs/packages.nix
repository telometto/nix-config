{ lib, config, ... }:
let
  base = [ ];

  desktop = [ ];

  media = [ ];

  productivity = [ ];

  social = [ ];

  development = [ ];

  extras = [ ];
in
{
  options.hm.programs.packages = {
    enable = lib.mkEnableOption "Shared Home Manager packages";

    additionalPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to install";
    };
  };

  config = lib.mkIf config.hm.programs.packages.enable {
    home.packages = lib.concatLists [
      base
      desktop
      media
      productivity
      social
      development
      extras
      config.hm.programs.packages.additionalPackages
    ];
  };
}
