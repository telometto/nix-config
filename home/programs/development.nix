{ lib, config, pkgs, VARS, ... }:
let cfg = config.hm.programs.development;
in {
  options.hm.programs.development = {
    enable = lib.mkEnableOption "Development tools and configuration";

    git = {
      userName = lib.mkOption {
        type = lib.types.str;
        default = VARS.users.admin.description or "Admin User";
        description = "Git user name";
      };

      userEmail = lib.mkOption {
        type = lib.types.str;
        default = "65364211+telometto@users.noreply.github.com";
        description = "Git user email";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      userName = cfg.git.userName;
      userEmail = cfg.git.userEmail;
      extraConfig = {
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

        user.signingKey = "${config.home.homeDirectory}/.ssh/github-key.pub";
      };

      includes = [{
        condition = "gitdir:~/.versioncontrol/github/";
        contents.user.email = "65364211+telometto@users.noreply.github.com";
      }];

      diff-so-fancy = { enable = true; };
    };

    home.packages = [
      # Development tools
      pkgs.nixd
      pkgs.vscode
      pkgs.jetbrains.idea-community-bin
      pkgs.ansible
    ];
  };
}
