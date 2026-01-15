{
  lib,
  config,
  pkgs,
  VARS,
  ...
}:
let
  cfg = config.hm.programs.development;
in
{
  options.hm.programs.development = {
    enable = lib.mkEnableOption "Development tools and configuration";

    git = {
      userName = lib.mkOption {
        type = lib.types.str;
        default = VARS.users.zeno.user or "Admin User";
        description = "Git user name";
      };

      userEmail = lib.mkOption {
        type = lib.types.str;
        default = "65364211+telometto@users.noreply.github.com";
        description = "Git user email";
      };

      lfs = lib.mkEnableOption "Git Large File Storage (LFS)";
    };

    gh = {
      enable = lib.mkEnableOption "GitHub CLI (gh)";

      gitProtocol = lib.mkOption {
        type = lib.types.enum [
          "ssh"
          "https"
        ];
        default = "ssh";
        description = "The protocol to use when performing Git operations";
      };

      aliases = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          co = "pr checkout";
          pv = "pr view";
          il = "issue list";
          iv = "issue view";
          ic = "issue create";
          rc = "repo clone";
          rv = "repo view";
        };
        description = "Aliases that allow you to create nicknames for gh commands";
      };

      gitCredentialHelper = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the gh git credential helper";
        };

        hosts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "https://github.com"
            "https://gist.github.com"
          ];
          description = "GitHub hosts to enable the gh git credential helper for";
        };
      };

      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "gh extensions to install";
      };

      extraSettings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional settings to add to the gh config.yml";
      };
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional development packages to install beyond the standard set";
      example = lib.literalExpression "[ pkgs.go pkgs.rustc ]";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      gh = lib.mkIf cfg.gh.enable {
        enable = lib.mkDefault true;

        settings = lib.mkMerge [
          {
            version = "1";
            git_protocol = cfg.gh.gitProtocol;
            prompt = "enabled";
            inherit (cfg.gh) aliases;
          }
          cfg.gh.extraSettings
        ];

        gitCredentialHelper = {
          inherit (cfg.gh.gitCredentialHelper) enable hosts;
        };

        inherit (cfg.gh) extensions;
      };

      git = {
        enable = lib.mkDefault true;

        settings = {
          user = {
            name = cfg.git.userName;
            email = cfg.git.userEmail;
            signingKey = "${config.home.homeDirectory}/.ssh/github-key.pub";
          };

          init.defaultBranch = "master";
          commit.gpgSign = true;
          tag.gpgSign = true;
          pull.rebase = false;

          gpg.format = "ssh";
        };

        includes = [
          {
            condition = "gitdir:~/.versioncontrol/github/";
            contents.user.email = "65364211+telometto@users.noreply.github.com";
          }
          {
            condition = "gitdir:~/.versioncontrol/gitea/";
            contents.user.email = "65364211+telometto@users.noreply.github.com";
          }
        ];

        lfs = {
          enable = lib.mkDefault cfg.git.lfs;

          skipSmudge = lib.mkDefault true;
        };
      };

      diff-so-fancy = {
        enable = lib.mkDefault true;
        enableGitIntegration = lib.mkDefault true;
      };
    };

    home.packages = lib.mkIf cfg.enable (
      [
        pkgs.nixd
        pkgs.ansible
      ]
      ++ cfg.extraPackages
    );
  };
}
