{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
# Single-owner Hyprland flavor under rewrite/, gated by telometto.desktop.flavor
let
  flavor = config.telometto.desktop.flavor or "none";
  is = v: flavor == v;
  haveHypr = inputs ? hyprland;
in
{
  config = lib.mkIf (is "hyprland") (
    lib.mkMerge [
      {
        # Enable Hyprland and align portal package with the input if present
        programs.hyprland.enable = true;

        # Wayland-friendly defaults
        xdg.portal = {
          enable = lib.mkDefault true;
          xdgOpenUsePortal = lib.mkDefault true;
          config.common.default = lib.mkDefault "*";
        };

        # Common tooling for Hyprland workflows
        environment.systemPackages = with pkgs; [
          # Core Hyprland ecosystem
          waybar
          hyprpaper
          hypridle
          hyprlock
          foot
          rofi

          # Wayland utilities
          wl-clipboard
          wl-clip-persist
          cliphist
          grimblast
          slurp
          grim

          # System tools
          brightnessctl
          playerctl
          pavucontrol
          networkmanagerapplet

          # File management
          xfce.thunar
          xfce.thunar-volman
          xfce.thunar-archive-plugin
          xfce.tumbler # Thumbnail support

          # Additional utilities
          libnotify # Send notifications
          wlr-randr # Display management
          wtype # xdotool for wayland
          # xwaylandvideobridge # Screen sharing
          qt5.qtwayland
          qt6.qtwayland
        ];

        # Enable required services
        services = {
          # Display manager - greetd with tuigreet for minimal setup
          greetd = {
            enable = lib.mkDefault true;
            settings = {
              default_session = {
                command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
                user = "greeter";
              };
            };
          };

          # PipeWire for audio
          pipewire = {
            enable = lib.mkDefault true;
            alsa.enable = lib.mkDefault true;
            alsa.support32Bit = lib.mkDefault true;
            pulse.enable = lib.mkDefault true;
            jack.enable = lib.mkDefault false;
          };

          # D-Bus for desktop integration
          dbus.enable = lib.mkDefault true;

          # Thumbnail support for file managers
          tumbler.enable = lib.mkDefault true;
        };

        # Security - polkit for privilege escalation
        security.polkit.enable = lib.mkDefault true;

        # Enable required programs
        programs = {
          dconf.enable = lib.mkDefault true; # Required for GTK apps
          xwayland.enable = lib.mkDefault true;
        };

        # Environment variables for Wayland
        environment.sessionVariables = {
          NIXOS_OZONE_WL = "1"; # Enable Wayland for Electron apps
          MOZ_ENABLE_WAYLAND = "1"; # Enable Wayland for Firefox
          _JAVA_AWT_WM_NONREPARENTING = "1"; # Fix for Java apps
          QT_QPA_PLATFORM = "wayland";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          SDL_VIDEODRIVER = "wayland";
          GDK_BACKEND = "wayland,x11";
        };

        # Fonts for waybar and other tools
        fonts.packages =
          with pkgs;
          [
            jetbrains-mono
            font-awesome
          ]
          ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);
      }

      # Only set Hyprland packages and portals when the hyprland input is present
      (lib.mkIf haveHypr {
        programs.hyprland.package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        programs.hyprland.portalPackage =
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
        xdg.portal.extraPortals = [
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
      })
    ]
  );
}
