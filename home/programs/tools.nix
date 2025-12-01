{ lib, config, ... }:
let
  cfg = config.hm.programs.tools;
in
{
  options.hm.programs.tools = {
    enable = lib.mkEnableOption "Utility tools and configuration";

    flameshot.enable = lib.mkEnableOption "Flameshot screenshot utility";
    texlive.enable = lib.mkEnableOption "LaTeX";
    onlyoffice.enable = lib.mkEnableOption "OnlyOffice (Office 365 alternative)";
    podman.enable = lib.mkEnableOption "Podman";
    jq.enable = lib.mkEnableOption "jq";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional utility packages to install";
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      flameshot = lib.mkIf cfg.flameshot.enable { enable = lib.mkDefault true; };
      podman = lib.mkIf cfg.podman.enable { enable = lib.mkDefault true; };
    };

    programs = {
      texlive = lib.mkIf cfg.texlive.enable { enable = lib.mkDefault true; };
      onlyoffice = lib.mkIf cfg.onlyoffice.enable { enable = lib.mkDefault true; };
      jq = lib.mkIf cfg.jq.enable { enable = lib.mkDefault true; };
    };

    home.packages = cfg.extraPackages;
  };
}
