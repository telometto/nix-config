{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.desktop.gnome;
in
{
  options.hm.desktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment configuration";

    extraExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional GNOME extensions to install";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional dconf settings";
    };
  };

  config = lib.mkIf cfg.enable {
    dconf.settings = lib.mkMerge [
      {
        # "org.blueman.plugins.powermanager" = { auto-power-on = false; };

        "org/gnome/shell" = {
          disable-user-extensions = false;
          app-picker-layout = "reset";
        };

        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          clock-show-weekday = true;
          font-antialiasing = "rgba";
          show-battery-percentage = true;
        };

        "org/gnome/desktop/datetime" = {
          automatic-timezone = true;
        };

        "org/gnome/desktop/peripherals/mouse" = {
          # speed = "-0.5";
          accel-profile = "flat";
        };

        "org/gtk/Settings/FileChooser" = {
          sort-directories-first = true;
        };

        "org/gnome/desktop/wm/preferences" = {
          button-layout = "appmenu:minimize,maximize,close";
        };

        "org/gnome/desktop/calendar" = {
          show-weekdate = true;
        };

        "system/proxy" = {
          mode = "auto";
        };

        "org/gnome/settings-daemon/plugins/color" = {
          night-light-enabled = true;
          night-light-schedule-automatic = true;
        };

        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-battery-type = "suspend";
          sleep-inactive-battery-timeout = 900;
          sleep-inactive-ac-type = "nothing";
        };

        "org/gnome/mutter" = {
          dynamic-workspaces = true;
          edge-tiling = true;
          experimental-features = [ "variable-refresh-rate" ];
        };
      }
      cfg.extraConfig
    ];

    home.packages = [
      pkgs.gnome-tweaks
      pkgs.wl-clipboard

      # GNOME extensions
      pkgs.gnomeExtensions.appindicator
      pkgs.gnomeExtensions.awesome-tiles
      pkgs.gnomeExtensions.burn-my-windows
      pkgs.gnomeExtensions.caffeine
      pkgs.gnomeExtensions.coverflow-alt-tab
      pkgs.gnomeExtensions.clipboard-indicator
      pkgs.gnomeExtensions.gsconnect
      pkgs.gnomeExtensions.openweather-refined
      pkgs.gnomeExtensions.proton-vpn-button
      pkgs.gnomeExtensions.status-area-horizontal-spacing
      pkgs.gnomeExtensions.tailscale-status
      pkgs.gnomeExtensions.thinkpad-battery-threshold
      pkgs.gnomeExtensions.tray-icons-reloaded
      pkgs.gnomeExtensions.user-themes
    ]
    ++ cfg.extraExtensions;

    # GTK theme configuration
    gtk = {
      enable = lib.mkDefault true;

      iconTheme = {
        name = "Yaru-dark";
        package = pkgs.yaru-theme;
      };

      theme = {
        name = "palenight";
        package = pkgs.palenight-theme;
      };

      cursorTheme = {
        name = "Numix-Cursor";
        package = pkgs.numix-cursor-theme;
      };

      # THIS
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };

    # XDG MIME associations from old config
    # xdg.mimeApps = {
    #   enable = true;
    #   defaultApplications = {
    #     "image/*" = [ "org.nomacs.ImageLounge.desktop" ];
    #   };
    # };
  };
}
