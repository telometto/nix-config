{
  lib,
  config,
  # pkgs,
  ...
}:
let
  cfg = config.telometto.programs.java;
in
{
  options.telometto.programs.java.enable = lib.mkEnableOption "Java (JDK) with JavaFX";
  config = lib.mkIf cfg.enable {
    programs.java = {
      enable = lib.mkDefault true;
      # package = lib.mkDefault (pkgs.jdk25.override { enableJavaFX = true; });
    };
  };
}
