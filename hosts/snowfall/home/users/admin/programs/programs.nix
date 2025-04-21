{ config, lib, pkgs, VARS, ... }:
let LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
in {
  programs = {
    firefox = {
      enable = false;

      languagePacks = LANGUAGES;

      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableFirefoxAccounts = false;
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
        DontCheckDefaultBrowser = true;
        DisplayBookmarksToolbar = "always";
        DisplayMenuBar = "default-off";
        SearchBar = "unified";

        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
      };
    };

    floorp = {
      enable = true;

      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableFirefoxAccounts = false;
        # OverrideFirstRunPage = "";
        # OverridePostUpdatePage = "";
        DontCheckDefaultBrowser = true;
        DisplayBookmarksToolbar = "always";
        DisplayMenuBar = "default-off";
        SearchBar = "unified";

        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
      };
    };

    ghostty = {
      enable = true;

      enableBashIntegration = true;
      enableZshIntegration = true;

      settings = { theme = "catppuccin-frappe"; };
    };

    git = {
      userName = "telometto";
      userEmail = config.sops.secrets."git/github-email".path;

      includes = [{
        condition = "gitdir:~/.versioncontrol/github/";

        contents = {
          user.name = "telometto";
          user.email = config.sops.secrets."git/github-email".path;

          commit.gpgSign = true;
        };
      }];
    };

    keychain = {
      keys = [
        "id_ed25519"
        "gitlabkey"
        "deployment-keys"
        "nix-secrets"
        "testkey"
        "github-key"
      ];
    };

    mangohud = { enable = true; };

    mpv = {
      enable = true;

      # TODO: Declaratively configure mpv
    };

    # SSH is on hold until config permissions are fixed; see https://github.com/nix-community/home-manager/issues/322

    # ssh = {
    #   enable = false;

    # extraConfig = ''
    #   AddKeysToAgent yes

    #   Host github.com
    #     Hostname ssh.github.com
    #     Port 443

    #   Host 192.168.*
    #     ForwardAgent yes
    #     IdentityFile /home/zeno/.ssh/id_ed25519
    #     IdentitiesOnly yes
    #     SetEnv TERM=xterm-256color
    # '';

    # addKeysToAgent = "yes";
    # # controlMaster = "auto";
    # # controlPath = "/some/path/%r@%h:%p";
    # # controlPersist = "yes";
    # compression = true;
    # # extraConfig = ""; # Strings concatenated with "\n"
    # # extraOptionOverrides = ""; # Attribute set of strings
    # forwardAgent = true;
    # # hashKnownHosts = true;
    # # includes = [ ]; # List of strings
    # # matchBlocks = { }; # Attribute set of attribute sets
    # # serverAliveCountMax = 1; # Positive integer
    # # serverAliveInterval = 1;
    # # userKnownHostsFile = ""; # String
    # };

    /* thunderbird = {
       enable = true;

       # TODO: Declaratively configure Thunderbird
       };
    */

    /* vscode = {
       enable = true;

       enableUpdateCheck = false; # Disable update checks
       mutableExtensionsDir = true; # Allow extensions to be installed in the user's home directory

       # TODO: Declaratively configure Visual Studio Code
       };
    */

    zellij = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      # TODO: Declaratively configure Zellij
      # settings = {
      #   theme = "gruvbox-dark";
      # };
    };

  };

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
}
