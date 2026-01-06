{
  lib,
  config,
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
    };

    home.packages = [ ];
  };
}
