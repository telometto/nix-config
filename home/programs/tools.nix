{ lib, config, ... }:
let
  cfg = config.hm.programs.tools;
in
{
  options.hm.programs.tools = {
    enable = lib.mkEnableOption "Gaming tools and configuration";

    flameshot.enable = lib.mkEnableOption "Flameshot screenshot utility";
    texlive.enable = lib.mkEnableOption "LaTeX";
    onlyoffice.enable = lib.mkEnableOption "OnlyOffice (Office 365 alternative)";
    podman.enable = lib.mkEnableOption "Podman";
    jq.enable = lib.mkEnableOption "jq";
  };

  config = lib.mkIf cfg.enable {
    services = {
      flameshot = lib.mkIf cfg.flameshot.enable { enable = true; };
      podman = lib.mkIf cfg.podman.enable { enable = true; };
    };

    programs = {
      texlive = lib.mkIf cfg.texlive.enable { enable = true; };
      onlyoffice = lib.mkIf cfg.onlyoffice.enable { enable = true; };
      jq = lib.mkIf cfg.jq.enable { enable = true; };
    };

    home.packages = [ ];
  };
}
