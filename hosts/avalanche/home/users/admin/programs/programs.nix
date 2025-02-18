{ config, lib, pkgs, VARS, ... }:
let
  LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
in
{
  programs = {
    firefox = {
      enable = true;

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

    git = {
      userName = "telometto";
      userEmail = config.sops.secrets."git/github-prim-email".path;

      includes = [
        {
          condition = "gitdir:~/.versioncontrol/github/";

          contents = {
            user.name = "telometto";
            user.email = config.sops.secrets."git/github-email".path;
            # user.signingKey = "0x5A5BF29378C3942B";

            commit.gpgSign = true;

            # core.sshCommand = "ssh -i ~/.ssh/id_ed25519";
          };
        }
        {
          condition = "gitdir:~/.versioncontrol/gitlab/";

          contents = {
            user.name = "telometto";
            user.email = config.sops.secrets."git/gitlab-email".path;
            # user.signingKey = "0xB7103B8A59566994";

            commit.gpgSign = true;

            # core.sshCommand = "ssh -i ~/.ssh/gitlabkey";
          };
        }
      ];
    };

    keychain = {
      keys = [
        "zeno-avalanche"
      ];
    };

    mangohud = {
      enable = true;
    };

    mpv = {
      enable = true;

      # TODO: Declaratively configure mpv
    };

    /*
      # SSH is on hold until config permissions are fixed; see https://github.com/nix-community/home-manager/issues/322
      # For now, resorting to non-home-manager configuration

      ssh = {
      enable = true;

      addKeysToAgent = "yes";
      #controlMaster = "auto";
      #controlPath = "/some/path/%r@%h:%p";
      #controlPersist = "yes";
      compression = true;
      #extraConfig = ""; # Strings concatenated with "\n"
      #extraOptionOverrides = ""; # Attribute set of strings
      forwardAgent = true;
      #hashKnownHosts = true;
      #includes = [ ]; # List of strings
      #matchBlocks = { }; # Attribute set of attribute sets
      #serverAliveCountMax = 1; # Positive integer
      #serverAliveInterval = 1;
      #userKnownHostsFile = ""; # String
      };
        */

    /*
      thunderbird = {
      enable = true;

      # TODO: Declaratively configure Thunderbird
      };
        */

    /*
      vscode = {
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
    "git/github-prim-email" = { path = "${config.sops.defaultSymlinkPath}/git/github-prim-email"; };
    "git/github-email" = { path = "${config.sops.defaultSymlinkPath}/git/github-email"; };
    "git/gitlab-email" = { path = "${config.sops.defaultSymlinkPath}/git/gitlab-email"; };
  };

}
