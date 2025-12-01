# Host-specific user overrides for blizzard (server)
{ lib, config, ... }:
{
  # Blizzard-specific user configuration
  # These settings will be applied to all users on this host

  programs.ssh.matchBlocks = {
    "*" = {
      addKeysToAgent = "yes";
      compression = false;
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      hashKnownHosts = false;
      userKnownHostsFile = "~/.ssh/known_hosts";
      controlMaster = "no";
      controlPath = "~/.ssh/master-%r@%n:%p";
      controlPersist = "no";
    };
    "github.com" = {
      hostname = "ssh.github.com";
      port = 443;
      user = "git";
      identitiesOnly = true;
      identityFile = "${config.home.homeDirectory}/.ssh/github-key";
    };
    "192.168.*" = {
      forwardAgent = true;
      identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
      identitiesOnly = true;
    };
  };

  hm = {
    # desktop = {
    #   xdg.enable = lib.mkForce false;
    #   # Desktop environments are auto-detected based on telometto.desktop.flavor
    #   # Individual DEs can be explicitly enabled/disabled per-user if needed
    # };

    programs = {
      browsers = {
        enable = lib.mkForce false;
        chromium.enable = lib.mkForce false;
      };

      # development.enable = lib.mkForce false;

      gaming = {
        enable = lib.mkForce false;
      };

      # gpg.enable = lib.mkForce false;

      media = {
        enable = lib.mkForce false;
        # mpv.enable = lib.mkForce false;
        # yt-dlp.enable = lib.mkForce false;
      };

      social = {
        enable = lib.mkForce false;
        # element-desktop.enable = lib.mkForce false;
        # vesktop.enable = lib.mkForce false;
      };

      # terminal.enable = lib.mkForce true;

      tools = {
        enable = lib.mkForce false;
        flameshot.enable = lib.mkForce false;
        texlive.enable = lib.mkForce false;
        onlyoffice.enable = lib.mkForce false;
        podman.enable = lib.mkForce false;
      };
    };

    # services = {
    #   gpgAgent.enable = lib.mkForce false;
    #   sshAgent.enable = lib.mkForce false;
    # };

    # security = {
    #   sops.enable = lib.mkForce false;
    # };
  };

  home = {
    stateVersion = lib.mkForce "24.11";
    # enableDebugInfo = lib.mkForce false;
    # preferXdgDirectories = lib.mkForce false;

    # Simple language defaults - can be overridden per user
    # language = {
    #   address = lib.mkForce locale;
    #   base = lib.mkForce locale;
    #   collate = lib.mkForce locale;
    #   ctype = lib.mkForce locale;
    #   measurement = lib.mkForce locale;
    #   messages = lib.mkForce locale;
    #   monetary = lib.mkForce locale;
    #   name = lib.mkForce locale;
    #   numeric = lib.mkForce locale;
    #   paper = lib.mkForce locale;
    #   telephone = lib.mkForce locale;
    #   time = lib.mkForce locale;
    # };

    # Default keyboard layout - can be overridden per user
    keyboard = {
      layout = lib.mkForce "no";
    };
  };

  # Example additional overrides:
  # hm.programs.terminal.extraPackages = with pkgs; [ server-tools ];
  # programs.git.extraConfig.blizzard = "server-setting";
}
