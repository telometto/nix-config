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
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional development packages to install beyond the standard set";
      example = lib.literalExpression "[ pkgs.go pkgs.rustc ]";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user = {
          inherit (cfg.git) userName userEmail;
          signingKey = "${config.home.homeDirectory}/.ssh/github-key.pub";
        };
        init.defaultBranch = "master";
        commit.gpgSign = true;
        tag.gpgSign = true;
        pull.rebase = true;

        gpg = {
          format = "ssh";
          # ssh = {
          #   defaultKeyCommand = "sh -c 'echo key::$(ssh-add -L | tail -n1)'";
          #   allowedSignersFile =
          #     "${config.home.homeDirectory}/.ssh/allowed_signers";
          # };
        };
      };

      includes = [
        {
          condition = "gitdir:~/.versioncontrol/github/";
          contents.user.email = "65364211+telometto@users.noreply.github.com";
        }
      ];
    };

    programs.diff-so-fancy = {
      enable = true;
      enableGitIntegration = true;
    };

    home.packages = lib.mkIf cfg.enable (
      [
        # Standard development tools
        pkgs.nixd
        pkgs.ansible
      ]
      ++ cfg.extraPackages
    );
  };
}
