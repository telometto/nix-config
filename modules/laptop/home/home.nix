{ config, lib, pkgs, myVars, ... }:

{
  home = {
    username = myVars.laptop.user;
    homeDirectory = "/home/${myVars.laptop.user}";
    stateVersion = "24.05";

    packages = with pkgs; [
      # Your packages here
      atuin
      bash
      bat
      #blesh
      direnv
      eza
      #firefox
      fzf
      nix-direnv
      sqlite
      zoxide

      # VS Code
      nixd # Nix language server for VS Code
      nixpkgs-fmt # Nix language formatter
      (vscode-with-extensions.override {
        vscodeExtensions = with vscode-extensions; [
          jnoortheen.nix-ide
          pkief.material-icon-theme
        ];
      })
    ];
  };

  dconf = {
    enable = true;

    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        clock-show-weekday = true;
        font-antialiasing = "rgba";
        gtk-theme = "Adwaita-dark";
      };

      "org/gnome/desktop/datetime" = {
        automatic-timezone = true;
        automatic-timezone-guess = true;
        automatic-timezone-guess-geoclue = true;
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

      "org/gnome/system/proxy" = {
        mode = "auto";
      };

      "org/gnome/settings-daemon/plugins.color" = {
        night-light-enabled = true;
        night-light-schedule-automatic = true;
      };
    };
  };

  programs = {
    home-manager = {
      enable = true;
    };

    atuin = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      #settings = {
      #  key_path = "/opt/sec/atuin-file";
      #};
    };

    bash = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true; # Enable VTE integration to track current directory
      historyControl = [ "erasedups" ]; # Remove duplicates in history
    };

    bat = {
      enable = true;
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      nix-direnv.enable = true;
    };

    eza = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      git = true;
      icons = "always";

      extraOptions = [
        "--group-directories-first"
        "--header"
        "--long"
      ];
    };

    fzf = {
      enable = true;

      tmux.enableShellIntegration = true;
    };

    firefox = {
      enable = true;
    };

    git = {
      enable = true;

      diff-so-fancy = {
        enable = true;
      };
    };

    gpg = {
      enable = true;
    };

    micro = {
      enable = true;

      settings = {
        autosu = true;
        mkparents = true;
        colorscheme = "gruvbox-tc";
        hlsearch = true;
        hltaberrors = true;
        tabtospaces = true;
      };
    };

    tmux = {
      enable = true;
      clock24 = true;
      mouse = true;

      #plugins = {
      #  dracula = {
      #    enable = true;
      #  };
      #
      #  gruvbox = {
      #    enable = true;
      #  };
      #};
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
  };
}
