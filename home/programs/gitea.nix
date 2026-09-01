# Opt-in user-level Git credentials for the private Gitea instance.
{
  lib,
  config,
  pkgs,
  VARS,
  ...
}:
let
  cfg = config.hm.programs.gitea;
  sopsEnabled = config.hm.security.sops.enable;
  sopsTarget =
    if config.sops.gnupg.home != null then "graphical-session-pre.target" else "default.target";
in
{
  options.hm.programs.gitea = {
    enable = lib.mkEnableOption "Gitea Git credential management";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = sopsEnabled;
        message = "hm.programs.gitea requires hm.security.sops.enable = true.";
      }
      {
        assertion = config.programs.git.enable;
        message = "hm.programs.gitea requires programs.git.enable = true.";
      }
    ];

    hm.security.sops.secrets = lib.mkIf sopsEnabled {
      "gitea/cf_access_id" = {
        mode = "0400";
      };

      "gitea/cf_access_secret" = {
        mode = "0400";
      };
    };

    sops.templates = lib.mkIf sopsEnabled {
      "gitea-git-http" = {
        content = ''
          [http "https://git.${VARS.domains.public}/"]
              extraHeader = CF-Access-Client-Id: ${config.sops.placeholder."gitea/cf_access_id"}
              extraHeader = CF-Access-Client-Secret: ${config.sops.placeholder."gitea/cf_access_secret"}
        '';
        mode = "0400";
      };
    };

    programs.git = lib.mkIf sopsEnabled {
      enable = lib.mkDefault true;
      package = lib.mkDefault (pkgs.git.override { withLibsecret = true; });

      # An empty helper resets inherited helpers before libsecret is used.
      settings.credential."https://git.${VARS.domains.public}".helper = [
        ""
        "libsecret"
      ];

      includes = [
        {
          path = config.sops.templates."gitea-git-http".path;
        }
      ];
    };

    # sops-nix is normally only WantedBy the target that starts it. Add the
    # ordering edge so the rendered include exists before user sessions run.
    systemd.user.services.sops-nix.Unit.Before = lib.mkIf sopsEnabled [ sopsTarget ];
  };
}
