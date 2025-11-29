{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.hm.desktop.hyprland;
in
{
  options.hm.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager configuration";

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Hyprland configuration";
    };

    extraBinds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional key bindings";
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = lib.mkDefault true;
      package = lib.mkDefault inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

      settings = lib.mkMerge [
        {
          "$mod" = "SUPER";
          bind = [
            "$mod, F, exec, firefox"
            ", Print, exec, grimblast copy area"
          ]
          ++ (
            # workspaces
            # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
            builtins.concatLists (
              builtins.genList (
                i:
                let
                  ws = i + 1;
                in
                [
                  "$mod, code:1${toString i}, workspace, ${toString ws}"
                  "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
                ]
              ) 9
            )
          )
          ++ cfg.extraBinds;
        }
        cfg.extraConfig
      ];
    };

    home.packages = [
      pkgs.grimblast
      pkgs.waybar
      pkgs.hyprpaper
      pkgs.hypridle
      pkgs.hyprlock
      pkgs.foot
      pkgs.wofi
    ];

    xdg.mimeApps = {
      enable = lib.mkDefault true;
      defaultApplications = {
        "image/*" = [ "org.nomacs.ImageLounge.desktop" ];
      };
    };
  };
}
