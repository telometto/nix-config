{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.programs.nix-ld;
in
{
  options.sys.programs.nix-ld = {
    enable = lib.mkEnableOption "nix-ld with comprehensive library support";

    extraLibraries = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional libraries to make available via nix-ld";
      example = lib.literalExpression "[ pkgs.libfoo pkgs.libbar ]";
    };

    includeDefaultLibraries = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include a comprehensive set of commonly-needed libraries";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nix-ld = {
      enable = lib.mkDefault true;
      libraries =
        with pkgs;
        [
          zlib
          zstd
          stdenv.cc.cc
          curl
          openssl
          attr
          libssh
          bzip2
          libxml2
          acl
          libsodium
          util-linux
          xz
          systemd
        ]
        ++ lib.optionals cfg.includeDefaultLibraries [
          # X11 libraries
          xorg.libXcomposite
          xorg.libXtst
          xorg.libXrandr
          xorg.libXext
          xorg.libX11
          xorg.libXfixes
          xorg.libxcb
          xorg.libXdamage
          xorg.libxshmfence
          xorg.libXxf86vm
          xorg.libXinerama
          xorg.libXcursor
          xorg.libXrender
          xorg.libXScrnSaver
          xorg.libXi
          xorg.libSM
          xorg.libICE
          xorg.libXt
          xorg.libXmu
          xorg.libXft

          # Graphics libraries
          libGL
          libva
          libgbm
          libdrm
          vulkan-loader
          libGLU

          # GTK and GUI libraries
          glib
          gtk2
          gtk3
          gdk-pixbuf
          cairo
          pango
          atk
          gnome2.GConf
          gsettings-desktop-schemas
          libnotify

          # Audio libraries
          pipewire
          alsa-lib
          libpulseaudio
          flac
          libogg
          libvorbis
          libmikmod
          libtheora
          speex
          libsamplerate

          # SDL libraries
          SDL
          SDL2
          SDL_image
          SDL_ttf
          SDL_mixer
          SDL2_image
          SDL2_ttf
          SDL2_mixer

          # Media and codec libraries
          ffmpeg
          libvpx
          libcaca
          libcanberra

          # Image libraries
          libjpeg
          libpng
          libpng12
          libtiff
          librsvg

          # Networking libraries
          networkmanager
          nspr
          nss
          cups
          dbus
          dbus-glib
          libidn

          # System libraries
          libelf
          libcap
          libusb1
          libudev0-shim
          libxcrypt
          libxcrypt-legacy
          coreutils
          pciutils
          e2fsprogs
          fuse

          # Desktop integration
          libappindicator-gtk2
          libdbusmenu-gtk2
          libindicator-gtk2

          # Other common libraries
          icu
          tbb
          pixman
          fontconfig
          freetype
          expat
          libgcrypt
          libvdpau
          libxkbcommon
          zenity
          freeglut
          glew
        ]
        ++ cfg.extraLibraries;
    };
  };
}
