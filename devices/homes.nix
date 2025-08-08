# Device and user specific home configurations
{ config, lib, pkgs, VARS, inputs, ... }:

let
  mylib = import ../lib { inherit lib VARS; };
  homePackages =
    import ../shared/home-packages.nix { inherit config lib pkgs VARS; };
  desktopPrograms = import ../home/programs/desktop-programs.nix {
    inherit config lib pkgs VARS;
  };
  laptopPrograms = import ../home/programs/laptop-programs.nix {
    inherit config lib pkgs VARS;
  };
  serverPrograms = import ../home/programs/server-programs.nix {
    inherit config lib pkgs VARS;
  };
  desktopServices = import ../home/services/desktop-services.nix {
    inherit config lib pkgs VARS;
  };
  laptopServices = import ../home/services/laptop-services.nix {
    inherit config lib pkgs VARS;
  };
  serverServices = import ../home/services/server-services.nix {
    inherit config lib pkgs VARS;
  };
  homeFiles = import ../home/files/files.nix { inherit config lib pkgs VARS; };
  LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
  LANG_NO = "nb_NO.UTF-8";
in {
  # User-specific configurations by device and user
  users = {
    # Admin user configurations per device
    admin = {
      snowfall = {
        colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

        home = {
          username = VARS.users.admin.user;
          stateVersion = "24.05";

          enableDebugInfo = true;
          preferXdgDirectories = true;

          packages = homePackages.base ++ homePackages.desktop;
          file = homeFiles.desktop;

          keyboard.layout = "no";
        };

        programs = desktopPrograms;
        services = desktopServices;

        sops.secrets = {
          "git/github-prim-email" = {
            path = "${config.sops.defaultSymlinkPath}/git/github-prim-email";
          };
          "git/github-email" = {
            path = "${config.sops.defaultSymlinkPath}/git/github-email";
          };
          "git/gitlab-email" = {
            path = "${config.sops.defaultSymlinkPath}/git/gitlab-email";
          };
        };
      };

      avalanche = {
        home = {
          username = VARS.users.admin.user;
          stateVersion = "24.05";

          enableDebugInfo = true;
          preferXdgDirectories = true;

          packages = homePackages.base ++ homePackages.laptop;
          file = homeFiles.laptop;

          keyboard.layout = "no";
        };

        programs = laptopPrograms.programs;
        services = laptopServices;

        sops.secrets = {
          "git/github-prim-email" = {
            path = "${config.sops.defaultSymlinkPath}/git/github-prim-email";
          };
          "git/github-email" = {
            path = "${config.sops.defaultSymlinkPath}/git/github-email";
          };
          "git/gitlab-email" = {
            path = "${config.sops.defaultSymlinkPath}/git/gitlab-email";
          };
        };
      };

      blizzard = {
        home = {
          username = VARS.users.admin.user;
          stateVersion = "24.11";

          enableDebugInfo = true;
          preferXdgDirectories = true;

          packages = homePackages.base ++ homePackages.server;
          file = homeFiles.server;

          keyboard.layout = "no";
        };

        programs = serverPrograms;
        services = serverServices;
      };
    };

    # Extra users configurations
    extra = {
      # Francesco (Italian user)
      francesco = {
        common = {
          home = {
            language = {
              address = "it_IT.UTF-8";
              base = "it_IT.UTF-8";
              collate = "it_IT.UTF-8";
              ctype = "it_IT.UTF-8";
              measurement = "it_IT.UTF-8";
              messages = "it_IT.UTF-8";
              monetary = "it_IT.UTF-8";
              name = "it_IT.UTF-8";
              numeric = "it_IT.UTF-8";
              paper = "it_IT.UTF-8";
              telephone = "it_IT.UTF-8";
              time = "it_IT.UTF-8";
            };

            packages = with pkgs; [ firefox libreoffice-still discord ];
          };
        };

        # Device-specific: prefers different DE on different devices
        snowfall = {
          # KDE + Hyprland on desktop
          wayland = {
            windowManager.hyprland = {
              enable = true;
              settings = {
                general = {
                  border_size = 2;
                  gaps_in = 5;
                  gaps_out = 10;
                };
              };
            };
          };
        };

        avalanche = {
          # GNOME on laptop for better power management
          dconf = {
            settings = {
              "org/gnome/desktop/interface" = {
                color-scheme = "prefer-dark";
                gtk-theme = "Adwaita-dark";
              };
            };
          };
        };
      };

      # Gianluca (Italian user)
      gianluca = {
        common = {
          home = {
            language = {
              address = "it_IT.UTF-8";
              base = "it_IT.UTF-8";
              collate = "it_IT.UTF-8";
              ctype = "it_IT.UTF-8";
              measurement = "it_IT.UTF-8";
              messages = "it_IT.UTF-8";
              monetary = "it_IT.UTF-8";
              name = "it_IT.UTF-8";
              numeric = "it_IT.UTF-8";
              paper = "it_IT.UTF-8";
              telephone = "it_IT.UTF-8";
              time = "it_IT.UTF-8";
            };

            packages = with pkgs; [ firefox libreoffice-still ];
          };
        };

        # Same DE preferences as Francesco
        snowfall = {
          wayland = {
            windowManager.hyprland = {
              enable = true;
              settings = {
                general = {
                  border_size = 2;
                  gaps_in = 5;
                  gaps_out = 10;
                };
              };
            };
          };
        };

        avalanche = {
          dconf = {
            settings = {
              "org/gnome/desktop/interface" = {
                color-scheme = "prefer-dark";
                gtk-theme = "Adwaita-dark";
              };
            };
          };
        };
      };

      # Wife (Norwegian user)  
      wife = {
        common = {
          home = {
            language = {
              address = "nb_NO.UTF-8";
              base = "nb_NO.UTF-8";
              collate = "nb_NO.UTF-8";
              ctype = "nb_NO.UTF-8";
              measurement = "nb_NO.UTF-8";
              messages = "nb_NO.UTF-8";
              monetary = "nb_NO.UTF-8";
              name = "nb_NO.UTF-8";
              numeric = "nb_NO.UTF-8";
              paper = "nb_NO.UTF-8";
              telephone = "nb_NO.UTF-8";
              time = "nb_NO.UTF-8";
            };

            packages = with pkgs; [ firefox libreoffice-still gimp ];
          };
        };

        # Prefers Hyprland on both devices
        snowfall = {
          wayland = {
            windowManager.hyprland = {
              enable = true;
              settings = {
                general = {
                  border_size = 1;
                  gaps_in = 3;
                  gaps_out = 8;
                };
              };
            };
          };
        };

        avalanche = {
          wayland = {
            windowManager.hyprland = {
              enable = true;
              settings = {
                general = {
                  border_size = 1;
                  gaps_in = 3;
                  gaps_out = 8;
                };
              };
            };
          };
        };
      };
    };
  };
}
