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

    monitor = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ",preferred,auto,1" ];
      description = "Monitor configuration";
      example = [
        "DP-1,1920x1080@144,0x0,1"
        "HDMI-A-1,1920x1080@60,1920x0,1"
      ];
    };

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

    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to wallpaper image";
    };

    terminal = lib.mkOption {
      type = lib.types.str;
      default = "foot";
      description = "Default terminal emulator";
    };

    launcher = lib.mkOption {
      type = lib.types.str;
      default = "rofi -show drun";
      description = "Application launcher command";
    };

    fileManager = lib.mkOption {
      type = lib.types.str;
      default = "thunar";
      description = "Default file manager";
    };

    waybar.enable = lib.mkEnableOption "Waybar status bar" // {
      default = true;
    };
    mako.enable = lib.mkEnableOption "Mako notification daemon" // {
      default = true;
    };
    rofi.enable = lib.mkEnableOption "Rofi launcher" // {
      default = true;
    };
    hypridle.enable = lib.mkEnableOption "Hypridle" // {
      default = true;
    };
    hyprlock.enable = lib.mkEnableOption "Hyprlock" // {
      default = true;
    };
    hyprpaper.enable = lib.mkEnableOption "Hyprpaper wallpaper daemon" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      # set the flake package
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

      settings = lib.mkMerge [
        {
          # Monitor configuration
          monitor = cfg.monitor;

          # Autostart
          exec-once = [
            "waybar"
            "mako"
            "hyprpaper"
            "hypridle"
          ];

          # Environment variables
          env = [
            "XCURSOR_SIZE,24"
            "HYPRCURSOR_SIZE,24"
            "QT_QPA_PLATFORM,wayland"
            "QT_QPA_PLATFORMTHEME,qt6ct"
            "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
            "GDK_BACKEND,wayland,x11,*"
            "SDL_VIDEODRIVER,wayland"
            "CLUTTER_BACKEND,wayland"
          ];

          # Input configuration
          input = {
            kb_layout = "us";
            follow_mouse = 1;
            sensitivity = 0; # -1.0 to 1.0, 0 means no modification
            touchpad = {
              natural_scroll = true;
              disable_while_typing = true;
              tap-to-click = true;
            };
          };

          # General window settings
          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
            "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
            "col.inactive_border" = "rgba(595959aa)";
            resize_on_border = true;
            allow_tearing = false;
            layout = "dwindle";
          };

          # Decoration settings
          decoration = {
            rounding = 10;
            active_opacity = 1.0;
            inactive_opacity = 0.95;
            drop_shadow = true;
            shadow_range = 4;
            shadow_render_power = 3;
            "col.shadow" = "rgba(1a1a1aee)";
            blur = {
              enabled = true;
              size = 3;
              passes = 1;
              vibrancy = 0.1696;
            };
          };

          # Animation settings
          animations = {
            enabled = true;
            bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
            animation = [
              "windows, 1, 7, myBezier"
              "windowsOut, 1, 7, default, popin 80%"
              "border, 1, 10, default"
              "borderangle, 1, 8, default"
              "fade, 1, 7, default"
              "workspaces, 1, 6, default"
            ];
          };

          # Layout settings
          dwindle = {
            pseudotile = true;
            preserve_split = true;
          };

          master = {
            new_status = "master";
          };

          # Gestures
          gestures = {
            workspace_swipe = true;
            workspace_swipe_fingers = 3;
          };

          # Miscellaneous
          misc = {
            force_default_wallpaper = 0;
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
          };

          # Variables
          "$mod" = "SUPER";
          "$terminal" = cfg.terminal;
          "$fileManager" = cfg.fileManager;
          "$menu" = cfg.launcher;

          # Key bindings
          bind = [
            # Application launchers
            "$mod, Return, exec, $terminal"
            "$mod, E, exec, $fileManager"
            "$mod, D, exec, $menu"
            "$mod, F, exec, firefox"

            # Window management
            "$mod, Q, killactive"
            "$mod, M, exit"
            "$mod, V, togglefloating"
            "$mod, P, pseudo" # dwindle
            "$mod, J, togglesplit" # dwindle
            "$mod, Fullscreen, fullscreen"

            # Focus movement
            "$mod, left, movefocus, l"
            "$mod, right, movefocus, r"
            "$mod, up, movefocus, u"
            "$mod, down, movefocus, d"
            "$mod, H, movefocus, l"
            "$mod, L, movefocus, r"
            "$mod, K, movefocus, u"
            "$mod SHIFT, J, movefocus, d"

            # Window movement
            "$mod SHIFT, left, movewindow, l"
            "$mod SHIFT, right, movewindow, r"
            "$mod SHIFT, up, movewindow, u"
            "$mod SHIFT, down, movewindow, d"
            "$mod SHIFT, H, movewindow, l"
            "$mod SHIFT, L, movewindow, r"
            "$mod SHIFT, K, movewindow, u"
            "$mod SHIFT CONTROL, J, movewindow, d"

            # Special workspace (scratchpad)
            "$mod, S, togglespecialworkspace, magic"
            "$mod SHIFT, S, movetoworkspace, special:magic"

            # Scroll through existing workspaces
            "$mod, mouse_down, workspace, e+1"
            "$mod, mouse_up, workspace, e-1"

            # Screenshots
            ", Print, exec, grimblast copy area"
            "SHIFT, Print, exec, grimblast copy screen"
            "CONTROL, Print, exec, grimblast copy window"

            # Media keys
            ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
            ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
            ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            ", XF86AudioPlay, exec, playerctl play-pause"
            ", XF86AudioPause, exec, playerctl play-pause"
            ", XF86AudioNext, exec, playerctl next"
            ", XF86AudioPrev, exec, playerctl previous"

            # Brightness
            ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
            ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"

            # Lock screen
            "$mod, BackSpace, exec, hyprlock"
          ]
          ++ (
            # Workspace bindings: $mod + [shift +] {1..9} to [move to] workspace {1..9}
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

          # Mouse bindings
          bindm = [
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
          ];

          # Window rules
          windowrulev2 = [
            "suppressevent maximize, class:.*"
            "float, class:^(thunar)$,title:^(File Operation Progress)$"
            "float, class:^(thunar)$,title:^(Confirm to replace files)$"
          ];
        }
        cfg.extraConfig
      ];
    };

    # Waybar configuration
    programs.waybar = lib.mkIf cfg.waybar.enable {
      enable = true;
      systemd.enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 35;
          spacing = 4;

          modules-left = [
            "hyprland/workspaces"
            "hyprland/window"
          ];
          modules-center = [ "clock" ];
          modules-right = [
            "pulseaudio"
            "network"
            "cpu"
            "memory"
            "temperature"
            "battery"
            "tray"
          ];

          "hyprland/workspaces" = {
            disable-scroll = false;
            all-outputs = true;
            format = "{icon}";
            format-icons = {
              "1" = "一";
              "2" = "二";
              "3" = "三";
              "4" = "四";
              "5" = "五";
              "6" = "六";
              "7" = "七";
              "8" = "八";
              "9" = "九";
              urgent = "";
              focused = "";
              default = "";
            };
          };

          "hyprland/window" = {
            format = "{}";
            separate-outputs = true;
            max-length = 50;
          };

          clock = {
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
            format = "{:%Y-%m-%d %H:%M}";
            format-alt = "{:%A, %B %d, %Y}";
          };

          cpu = {
            format = " {usage}%";
            tooltip = false;
          };

          memory = {
            format = " {}%";
          };

          temperature = {
            critical-threshold = 80;
            format = "{icon} {temperatureC}°C";
            format-icons = [
              ""
              ""
              ""
            ];
          };

          battery = {
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{icon} {capacity}%";
            format-charging = " {capacity}%";
            format-plugged = " {capacity}%";
            format-alt = "{icon} {time}";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
          };

          network = {
            format-wifi = " {essid} ({signalStrength}%)";
            format-ethernet = " {ifname}";
            format-disconnected = "⚠ Disconnected";
            tooltip-format = "{ifname}: {ipaddr}/{cidr}";
            format-linked = "{ifname} (No IP)";
          };

          pulseaudio = {
            scroll-step = 5;
            format = "{icon} {volume}%";
            format-bluetooth = "{icon} {volume}%";
            format-muted = "";
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "";
              car = "";
              default = [
                ""
                ""
                ""
              ];
            };
            on-click = "pavucontrol";
          };

          tray = {
            icon-size = 18;
            spacing = 10;
          };
        };
      };

      style = ''
        * {
          border: none;
          border-radius: 0;
          font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
          font-size: 13px;
          min-height: 0;
        }

        window#waybar {
          background-color: rgba(43, 48, 59, 0.95);
          color: #ffffff;
          transition-property: background-color;
          transition-duration: 0.5s;
        }

        #workspaces button {
          padding: 0 5px;
          background-color: transparent;
          color: #ffffff;
          border-bottom: 3px solid transparent;
        }

        #workspaces button.active {
          background-color: rgba(0, 0, 0, 0.3);
          border-bottom: 3px solid #ffffff;
        }

        #workspaces button.urgent {
          background-color: #eb4d4b;
        }

        #clock,
        #battery,
        #cpu,
        #memory,
        #temperature,
        #network,
        #pulseaudio,
        #tray,
        #window {
          padding: 0 10px;
          margin: 0 4px;
          color: #ffffff;
        }

        #battery.charging {
          color: #26a65b;
        }

        #battery.warning:not(.charging) {
          color: #f39c12;
        }

        #battery.critical:not(.charging) {
          color: #e74c3c;
          animation: blink 0.5s linear infinite alternate;
        }

        @keyframes blink {
          to {
            color: #ffffff;
          }
        }

        #cpu {
          color: #2ecc71;
        }

        #memory {
          color: #9b59b6;
        }

        #temperature {
          color: #f39c12;
        }

        #temperature.critical {
          color: #e74c3c;
        }

        #network {
          color: #3498db;
        }

        #network.disconnected {
          color: #e74c3c;
        }

        #pulseaudio {
          color: #1abc9c;
        }

        #pulseaudio.muted {
          color: #95a5a6;
        }
      '';
    };

    # Mako notification daemon
    services.mako = lib.mkIf cfg.mako.enable {
      enable = true;
      backgroundColor = "#2b303bdd";
      textColor = "#ffffff";
      borderColor = "#3498db";
      borderSize = 2;
      borderRadius = 10;
      defaultTimeout = 5000;
      width = 400;
      height = 150;
      margin = "10";
      padding = "15";
      font = "sans-serif 12";
      layer = "overlay";
      anchor = "top-right";

      extraConfig = ''
        [urgency=high]
        border-color=#e74c3c
        default-timeout=0
      '';
    };

    # Rofi launcher
    programs.rofi = lib.mkIf cfg.rofi.enable {
      enable = true;
      package = pkgs.rofi;
      theme = "Arc-Dark";
      terminal = cfg.terminal;
      extraConfig = {
        modi = "drun,run,window,ssh";
        show-icons = true;
        display-drun = " Apps";
        display-run = " Run";
        display-window = " Windows";
        display-ssh = " SSH";
        drun-display-format = "{name}";
        window-format = "{w} · {c} · {t}";
      };
    };

    # Hypridle configuration
    services.hypridle = lib.mkIf cfg.hypridle.enable {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };

        listener = [
          {
            timeout = 300; # 5 minutes
            on-timeout = "brightnessctl -s set 10";
            on-resume = "brightnessctl -r";
          }
          {
            timeout = 600; # 10 minutes
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 900; # 15 minutes
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
          {
            timeout = 1800; # 30 minutes
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };

    # Hyprlock configuration
    programs.hyprlock = lib.mkIf cfg.hyprlock.enable {
      enable = true;
      settings = {
        general = {
          disable_loading_bar = false;
          grace = 10;
          hide_cursor = true;
          no_fade_in = false;
        };

        background = [
          {
            monitor = "";
            path = if cfg.wallpaper != null then toString cfg.wallpaper else "screenshot";
            blur_passes = 3;
            blur_size = 8;
          }
        ];

        input-field = [
          {
            monitor = "";
            size = "300, 50";
            position = "0, -80";
            dots_center = true;
            fade_on_empty = false;
            font_color = "rgb(202, 211, 245)";
            inner_color = "rgb(91, 96, 120)";
            outer_color = "rgb(24, 25, 38)";
            outline_thickness = 5;
            placeholder_text = ''<span foreground="##cad3f5">Password...</span>'';
            shadow_passes = 2;
          }
        ];

        label = [
          {
            monitor = "";
            text = "$TIME";
            color = "rgba(200, 200, 200, 1.0)";
            font_size = 55;
            font_family = "JetBrains Mono Nerd Font";
            position = "0, 80";
            halign = "center";
            valign = "center";
          }
        ];
      };
    };

    # Hyprpaper configuration
    services.hyprpaper = lib.mkIf (cfg.hyprpaper.enable && cfg.wallpaper != null) {
      enable = true;
      settings = {
        ipc = "on";
        splash = false;
        splash_offset = 2.0;

        preload = [ "${cfg.wallpaper}" ];
        wallpaper = [ ",${cfg.wallpaper}" ];
      };
    };

    home.packages =
      with pkgs;
      [
        # Core Hyprland tools
        grimblast # Screenshot tool
        wl-clipboard # Wayland clipboard utilities
        cliphist # Clipboard history

        # System utilities
        brightnessctl # Brightness control
        playerctl # Media player control
        pavucontrol # PulseAudio volume control
        networkmanagerapplet # Network manager tray

        # File managers and utilities
        xfce.thunar
        xfce.thunar-volman
        xfce.thunar-archive-plugin

        # Additional tools
        wlr-randr # Display configuration
        wtype # xdotool for wayland

        # Fonts for waybar
        jetbrains-mono
        font-awesome
      ]
      ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

    # XDG MIME associations
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "image/*" = [ "org.nomacs.ImageLounge.desktop" ];
        "text/html" = [ "firefox.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
        "x-scheme-handler/about" = [ "firefox.desktop" ];
        "x-scheme-handler/unknown" = [ "firefox.desktop" ];
        "inode/directory" = [ "thunar.desktop" ];
      };
    };

    # Note: XDG portals are configured at the system level in modules/desktop/flavors/hyprland.nix
    # Do not configure them here to avoid conflicts
  };
}
