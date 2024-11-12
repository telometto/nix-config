{ config, lib, pkgs, myVars, ... }:

{
  home.packages = with pkgs; [
    gnome-tweaks

    # GNOME extensions
    gnomeExtensions.user-themes
    gnomeExtensions.tray-icons-reloaded
    gnomeExtensions.appindicator
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.tailscale-status
    gnomeExtensions.openweather-refined
    gnomeExtensions.burn-my-windows
    #gnomeExtensions.
  ];

  dconf = {
    enable = true;

    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;

        #enabled-extensions = { };
      };

      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        clock-show-weekday = true;
        font-antialiasing = "rgba";
        #gtk-theme = "Adwaita-dark";
      };

      "org/gnome/desktop/datetime" = {
        automatic-timezone = true;
        #automatic-timezone-guess = true;
        #automatic-timezone-guess-geoclue = true;
      };

      "org/gnome/desktop/peripherals/mouse" = {
        #speed = "-0.5";
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
    };
  };

  gtk = {
    enable = true;

    iconTheme = {
      name = "Yaru-dark"; # "Papirus-Dark";
      package = pkgs.yaru-theme; # pkgs.papirus-icon-theme;
    };

    theme = {
      name = "palenight";
      package = pkgs.palenight-theme;
    };

    cursorTheme = {
      name = "Numix-Cursor";
      package = pkgs.numix-cursor-theme;
    };

    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };

    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
  };
}
