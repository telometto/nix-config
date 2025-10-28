# Example Hyprland user configuration
# This file demonstrates various Hyprland customization options
# Copy this to your actual user config file and customize as needed

{
  lib,
  config,
  pkgs,
  ...
}:
{
  # Example packages you might want with Hyprland
  home.packages = with pkgs; [
    # Additional terminals
    alacritty
    kitty

    # Browsers
    firefox
    chromium

    # Image viewers
    imv

    # Video players
    mpv

    # PDF viewers
    zathura

    # Screenshot annotation
    swappy

    # Color picker
    hyprpicker

    # System monitoring
    btop

    # File managers (thunar is included by default)
    nautilus
  ];

  # Hyprland configuration
  hm.desktop = {
    # Enable XDG directories (required for Hyprland)
    xdg.enable = true;

    hyprland = {
      enable = true;

      # ====================================
      # Monitor Configuration
      # ====================================
      # Run 'hyprctl monitors' to see your monitor names
      monitor = [
        # Format: name,resolution@refresh,position,scale
        # "DP-1,1920x1080@144,0x0,1"
        # "HDMI-A-1,1920x1080@60,1920x0,1"
        ",preferred,auto,1" # Fallback for all monitors
      ];

      # ====================================
      # Application Settings
      # ====================================
      terminal = "foot"; # or "alacritty", "kitty", etc.
      launcher = "rofi -show drun"; # or "wofi --show drun"
      fileManager = "thunar"; # or "nautilus"

      # Set wallpaper (optional)
      # wallpaper = ./wallpapers/my-wallpaper.jpg;

      # ====================================
      # Component Toggles
      # ====================================
      waybar.enable = true; # Status bar
      mako.enable = true; # Notifications
      rofi.enable = true; # Application launcher
      hypridle.enable = true; # Idle management
      hyprlock.enable = true; # Screen locker
      hyprpaper.enable = true; # Wallpaper daemon

      # ====================================
      # Custom Keybindings
      # ====================================
      extraBinds = [
        # Additional terminals
        "$mod, T, exec, alacritty"
        "$mod SHIFT, Return, exec, kitty"

        # Additional browsers
        "$mod, B, exec, brave"
        "$mod SHIFT, B, exec, chromium"

        # Media
        "$mod, N, exec, thunar ~/Music"

        # Utilities
        "$mod, C, exec, hyprpicker -a" # Color picker
        "$mod SHIFT, S, exec, grimblast copy area | swappy -f -" # Screenshot with annotation

        # Reload Hyprland
        "$mod SHIFT, R, exec, hyprctl reload"

        # Volume control (alternative bindings)
        "$mod, equal, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        "$mod, minus, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ];

      # ====================================
      # Advanced Hyprland Configuration
      # ====================================
      extraConfig = {
        # ---- Input Configuration ----
        input = {
          kb_layout = "us"; # Change to your layout
          # kb_variant = "";
          # kb_options = "caps:escape"; # Make Caps Lock act as Escape

          sensitivity = 0.0; # Mouse sensitivity (-1.0 to 1.0)
          accel_profile = "flat"; # or "adaptive"

          touchpad = {
            natural_scroll = true;
            disable_while_typing = true;
            tap-to-click = true;
            middle_button_emulation = false;
            clickfinger_behavior = false;
          };
        };

        # ---- Appearance ----
        general = {
          # Gaps
          gaps_in = 5;
          gaps_out = 10;

          # Border
          border_size = 2;
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";

          # Layout
          layout = "dwindle"; # or "master"

          # Resize
          resize_on_border = true;
          extend_border_grab_area = 15;

          # Allow tearing for games
          allow_tearing = false; # Set to true for gaming
        };

        # ---- Decorations ----
        decoration = {
          rounding = 10;

          # Opacity
          active_opacity = 1.0;
          inactive_opacity = 0.95;
          fullscreen_opacity = 1.0;

          # Shadow
          drop_shadow = true;
          shadow_range = 4;
          shadow_render_power = 3;
          "col.shadow" = "rgba(1a1a1aee)";

          # Dim inactive windows
          dim_inactive = false;
          dim_strength = 0.1;

          # Blur
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
            vibrancy = 0.1696;
            ignore_opacity = false;
            new_optimizations = true;
          };
        };

        # ---- Animations ----
        animations = {
          enabled = true;

          bezier = [
            "myBezier, 0.05, 0.9, 0.1, 1.05"
            "linear, 0.0, 0.0, 1.0, 1.0"
            "easeInOut, 0.42, 0.0, 0.58, 1.0"
          ];

          animation = [
            "windows, 1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "borderangle, 1, 8, default"
            "fade, 1, 7, default"
            "workspaces, 1, 6, default"
            "specialWorkspace, 1, 6, default, slidevert"
          ];
        };

        # ---- Dwindle Layout ----
        dwindle = {
          pseudotile = true; # Enable pseudotiling
          preserve_split = true; # Keep split direction
          smart_split = false;
          smart_resizing = true;
        };

        # ---- Master Layout ----
        master = {
          new_status = "master"; # or "slave"
          new_on_top = false;
          mfact = 0.55; # Master area size (0.0 - 1.0)
        };

        # ---- Gestures ----
        gestures = {
          workspace_swipe = true;
          workspace_swipe_fingers = 3;
          workspace_swipe_distance = 300;
          workspace_swipe_cancel_ratio = 0.5;
          workspace_swipe_create_new = true;
        };

        # ---- Miscellaneous ----
        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          force_default_wallpaper = 0;
          vfr = true; # Variable refresh rate
          vrr = 0; # Variable refresh rate (0 = off, 1 = on, 2 = fullscreen only)
          mouse_move_enables_dpms = true;
          key_press_enables_dpms = true;
          enable_swallow = false; # Window swallowing
          swallow_regex = "^(foot|kitty|alacritty)$";
        };

        # ---- Window Rules ----
        windowrulev2 = [
          # Suppress maximize events (Hyprland uses fullscreen)
          "suppressevent maximize, class:.*"

          # Float specific windows
          "float, class:^(pavucontrol)$"
          "float, class:^(nm-connection-editor)$"
          "float, class:^(blueman-manager)$"
          "float, title:^(Picture-in-Picture)$"

          # Thunar file operations
          "float, class:^(thunar)$,title:^(File Operation Progress)$"
          "float, class:^(thunar)$,title:^(Confirm to replace files)$"

          # Size specific windows
          "size 800 600, class:^(pavucontrol)$"
          "size 600 400, class:^(nm-connection-editor)$"

          # Center specific windows
          "center, class:^(pavucontrol)$"
          "center, class:^(nm-connection-editor)$"

          # Pin Picture-in-Picture
          "pin, title:^(Picture-in-Picture)$"
          "keepaspectratio, title:^(Picture-in-Picture)$"

          # XWayland video bridge (for screen sharing)
          "opacity 0.0 override, class:^(xwaylandvideobridge)$"
          "noanim, class:^(xwaylandvideobridge)$"
          "noinitialfocus, class:^(xwaylandvideobridge)$"
          "maxsize 1 1, class:^(xwaylandvideobridge)$"
          "noblur, class:^(xwaylandvideobridge)$"

          # Gaming rules (example)
          # "immediate, class:^(steam_app_).*" # Allow tearing
          # "fullscreen, class:^(steam_app_).*"
          # "workspace 5 silent, class:^(steam_app_).*"

          # Workspace assignments (example)
          # "workspace 1 silent, class:^(firefox)$"
          # "workspace 2 silent, class:^(code)$"
          # "workspace 3 silent, class:^(discord)$"
          # "workspace 4 silent, class:^(spotify)$"
        ];

        # ---- Layer Rules ----
        layerrule = [
          "blur, waybar"
          "ignorezero, waybar"
          "blur, rofi"
          "ignorezero, rofi"
          "blur, notifications"
          "ignorezero, notifications"
        ];

        # ---- Workspace Rules ----
        workspace = [
          # Assign default workspaces to specific monitors
          # "1, monitor:DP-1, default:true"
          # "4, monitor:HDMI-A-1, default:true"

          # Persistent workspaces
          # "1, persistent:true"
          # "2, persistent:true"
        ];
      };
    };
  };

  # ====================================
  # Additional Program Configurations
  # ====================================

  # Override Waybar configuration
  programs.waybar = lib.mkIf config.hm.desktop.hyprland.enable {
    # You can override the waybar settings here
    # settings.mainBar.modules-right = [ ... ];
  };

  # Override Mako configuration
  services.mako = lib.mkIf config.hm.desktop.hyprland.enable {
    # You can override the mako settings here
    # defaultTimeout = 10000;
    # anchor = "top-center";
  };

  # Override Rofi configuration
  programs.rofi = lib.mkIf config.hm.desktop.hyprland.enable {
    # You can override the rofi settings here
    # theme = "gruvbox-dark";
  };

  # Override Hypridle configuration
  services.hypridle = lib.mkIf config.hm.desktop.hyprland.enable {
    # You can override the hypridle settings here
    # settings.listener = [ ... ];
  };

  # ====================================
  # Additional Services
  # ====================================

  # Example: Start additional services with Hyprland
  # systemd.user.services.my-custom-service = {
  #   Unit = {
  #     Description = "My Custom Service";
  #     After = [ "graphical-session.target" ];
  #   };
  #   Service = {
  #     ExecStart = "${pkgs.my-package}/bin/my-command";
  #     Restart = "on-failure";
  #   };
  #   Install = {
  #     WantedBy = [ "graphical-session.target" ];
  #   };
  # };
}
