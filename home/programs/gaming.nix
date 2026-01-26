{
  lib,
  config,
  pkgs,
  osConfig,
  ...
}:
let
  cfg = config.hm.programs.gaming;
in
{
  options.hm.programs.gaming = {
    enable = lib.mkEnableOption "Gaming tools and configuration";

    mangohud = {
      enable = lib.mkEnableOption "MangoHud performance overlay";

      extraSettings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional mangohud extra settings merged with the shared defaults.";
      };
    };

    lutris = {
      enable = lib.mkEnableOption "Game library manager";
      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          winetricks
          gamescope
          gamemode
          mangohud
          umu-launcher
        ];
        description = "List of extra packages to configure for Lutris";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      mangohud = lib.mkIf cfg.mangohud.enable {
        enable = lib.mkDefault true;

        settings = {
          time = true;
          time_no_label = true;

          gpu_stats = true;
          gpu_temp = true;
          gpu_text = "GPU";
          gpu_load_change = true;
          gpu_load_color = "39F900,FDFD09,B22222";

          cpu_stats = true;
          cpu_temp = true;
          cpu_text = "CPU";
          cpu_load_change = true;
          cpu_load_color = "39F900,FDFD09,B22222";

          vram = true;
          ram = true;

          fps = true;
          fps_color_change = true;
          fps_color = "B22222,FDFD09,39F900";
          frametime = true;

          throttling_status = true;
          frame_timing = true;
          gamemode = true;

          media_player = true;
          media_player_name = "spotify";
          media_player_format = "title,artist,album";

          text_outline = true;
        }
        // cfg.mangohud.extraSettings;
      };

      lutris = lib.mkIf cfg.lutris.enable {
        enable = lib.mkDefault true;

        defaultWinePackage = pkgs.proton-ge-bin;

        winePackages = with pkgs; [
          wineWowPackages.stagingFull
          wineWowPackages.waylandFull
          wineWowPackages.fonts
        ];

        protonPackages = [ pkgs.proton-ge-bin ];

        steamPackage = osConfig.programs.steam.package;

        inherit (cfg.lutris) extraPackages;
      };
    };

    home.packages = [ pkgs.bbe ];
  };
}
