{ lib, config, ... }:
let
  cfg = config.hm;
  regionalLocale = cfg.langs;
in
{
  options.hm.langs = lib.mkOption {
    type = lib.types.str;
    default = "en_US.UTF-8";
    description = "Regional locale for formatting; does not change the UI language";
  };

  config = {
    # Base home-manager configuration with sensible defaults
    # Import this in your user configurations for automatic defaults
    programs.home-manager.enable = true;

    hm = {
      desktop = {
        xdg.enable = lib.mkDefault true;
      };

      programs = {
        browsers = {
          enable = lib.mkDefault true;
          chromium.enable = lib.mkDefault true;
        };

        development = {
          enable = lib.mkDefault true;
          gh.enable = lib.mkDefault true;
        };

        gaming = {
          enable = lib.mkDefault true;
          mangohud.enable = lib.mkDefault true;
        };

        gpg.enable = lib.mkDefault true;

        media = {
          enable = lib.mkDefault true;
          mpv.enable = lib.mkDefault true;
          yt-dlp.enable = lib.mkDefault true;
          jf-mpv.enable = lib.mkDefault true;
          obs.enable = lib.mkDefault true;
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
          podman.enable = lib.mkDefault true;
          jq.enable = lib.mkDefault true;
        };
      };

      services = {
        gpgAgent.enable = lib.mkDefault true;
        sshAgent.enable = lib.mkDefault false;
      };

      security = {
        sops.enable = lib.mkDefault true;
      };

      accounts = {
        email.enable = lib.mkDefault false;
        calendar.enable = lib.mkDefault false;
        contact.enable = lib.mkDefault false;
      };
    };

    home = {
      stateVersion = lib.mkDefault "24.05";
      preferXdgDirectories = lib.mkDefault true;

      language = {
        address = lib.mkDefault regionalLocale;
        base = lib.mkDefault "en_US.UTF-8";
        collate = lib.mkDefault regionalLocale;
        ctype = lib.mkDefault regionalLocale;
        measurement = lib.mkDefault regionalLocale;
        messages = lib.mkDefault "en_US.UTF-8";
        monetary = lib.mkDefault regionalLocale;
        name = lib.mkDefault regionalLocale;
        numeric = lib.mkDefault regionalLocale;
        paper = lib.mkDefault regionalLocale;
        telephone = lib.mkDefault regionalLocale;
        time = lib.mkDefault regionalLocale;
      };

      keyboard.layout = lib.mkDefault "no";
    };
  };
}
