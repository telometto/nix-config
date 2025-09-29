{ lib, config, ... }:
let
  cfg = config.hm;
  locale = cfg.langs;
in
{
  options.hm.langs = lib.mkOption {
    type = lib.types.str;
    default = "en_US.UTF-8";
    description = "Default locale";
  };

  config = {
    # Base home-manager configuration with sensible defaults
    # Import this in your user configurations for automatic defaults
    programs.home-manager.enable = lib.mkDefault true;

    # Set sensible defaults for home-manager modules
    # These can be overridden per-user as needed
    hm = {
      desktop = {
        xdg.enable = lib.mkDefault true;
        # Desktop environments are auto-detected based on telometto.desktop.flavor
        # Individual DEs can be explicitly enabled/disabled per-user if needed
      };

      programs = {
        browsers = {
          enable = lib.mkDefault true;
          chromium.enable = lib.mkDefault true;
        };

        development.enable = lib.mkDefault true;

        gaming = {
          enable = lib.mkDefault true;
          mangohud.enable = lib.mkDefault true;
        };

        gpg.enable = lib.mkDefault true;

        media = {
          enable = lib.mkDefault true;
          mpv.enable = lib.mkDefault true;
        };

        social = {
          enable = lib.mkDefault true;
          element-desktop.enable = lib.mkDefault true;
          vesktop.enable = lib.mkDefault true;
        };

        terminal.enable = lib.mkDefault true;

        tools = {
          enable = lib.mkDefault true;
          onlyoffice.enable = lib.mkDefault true;
        };
      };

      services = {
        gpgAgent.enable = lib.mkDefault true;
        sshAgent.enable = lib.mkDefault true;
      };

      security = {
        sops.enable = lib.mkDefault true;
      };
    };

    home = {
      stateVersion = lib.mkDefault "24.05";
      enableDebugInfo = lib.mkDefault true;
      preferXdgDirectories = lib.mkDefault true;

      # Simple language defaults - can be overridden per user
      language = {
        address = lib.mkDefault locale;
        base = lib.mkDefault locale;
        collate = lib.mkDefault locale;
        ctype = lib.mkDefault locale;
        measurement = lib.mkDefault locale;
        messages = lib.mkDefault locale;
        monetary = lib.mkDefault locale;
        name = lib.mkDefault locale;
        numeric = lib.mkDefault locale;
        paper = lib.mkDefault locale;
        telephone = lib.mkDefault locale;
        time = lib.mkDefault locale;
      };

      # Default keyboard layout - can be overridden per user
      keyboard = {
        layout = lib.mkDefault "no";
      };
    };
  };
}
