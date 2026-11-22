{
  lib,
  config,
  ...
}:
let
  cfg = config.hm.accounts.email;

  # Collect sops secret keys from all accounts that define passwordSopsSecret
  accountsWithSops = lib.filterAttrs (_: acct: acct.passwordSopsSecret != null) cfg.accounts;

  emailAccountSubmodule = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this email account is enabled.";
      };

      primary = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this is the primary email account.";
      };

      flavor = lib.mkOption {
        type = lib.types.enum [
          "davmail"
          "fastmail.com"
          "gmail.com"
          "mailbox.org"
          "migadu.com"
          "outlook.office365.com"
          "plain"
          "posteo.de"
          "runbox.com"
          "yandex.com"
        ];
        default = "plain";
        description = "Email provider flavor for automatic IMAP/SMTP server configuration.";
      };

      address = lib.mkOption {
        type = lib.types.strMatching ".*@.*";
        description = "The email address of this account.";
      };

      realName = lib.mkOption {
        type = lib.types.str;
        default = cfg.defaults.realName;
        defaultText = lib.literalExpression "config.hm.accounts.email.defaults.realName";
        description = "Name displayed when sending mails.";
      };

      userName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The server username. Defaults to address for most flavors.";
      };

      passwordSopsSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "accounts/email/gmail/password";
        description = ''
          SOPS secret key for this account's password. When set, the module
          auto-registers the secret in hm.security.sops.secrets and wires
          passwordCommand to read from the decrypted secret path.
        '';
      };

      passwordCommand = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
        default = null;
        description = ''
          A command that prints the account password on stdout. If
          passwordSopsSecret is set, this is auto-populated and should
          not be set manually.
        '';
      };

      imap = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = "IMAP configuration. Auto-set for known flavors.";
      };

      smtp = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = "SMTP configuration. Auto-set for known flavors.";
      };

      jmap = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = "JMAP configuration.";
      };

      gpg = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = cfg.defaults.gpg;
        defaultText = lib.literalExpression "config.hm.accounts.email.defaults.gpg";
        description = "GPG configuration for this account.";
      };

      signature = lib.mkOption {
        type = lib.types.attrs;
        default = cfg.defaults.signature;
        defaultText = lib.literalExpression "config.hm.accounts.email.defaults.signature";
        description = "Signature configuration for this account.";
      };

      folders = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Standard email folder names (inbox, sent, drafts, trash).";
      };

      maildir = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = "Maildir configuration. Defaults to account name.";
      };

      aliases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Alternative email addresses for this account.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Extra attributes merged into the upstream accounts.email.accounts entry.";
      };
    };
  };
in
{
  options.hm.accounts.email = {
    enable = lib.mkEnableOption "Declarative email account management";

    maildirBasePath = lib.mkOption {
      type = lib.types.str;
      default = "Maildir";
      description = "Base directory for account maildir directories, relative to home.";
    };

    defaults = {
      realName = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Default display name for email accounts.";
      };

      gpg = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        description = "Default GPG configuration applied to all accounts.";
      };

      signature = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Default signature configuration applied to all accounts.";
      };
    };

    accounts = lib.mkOption {
      type = lib.types.attrsOf emailAccountSubmodule;
      default = { };
      description = "Email accounts to configure via home-manager's accounts.email.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.mapAttrsToList (name: acct: {
        assertion = !(acct.passwordSopsSecret != null && acct.passwordCommand != null);
        message = "hm.accounts.email.accounts.${name}: passwordSopsSecret and passwordCommand are mutually exclusive.";
      }) cfg.accounts
      ++ lib.optional (accountsWithSops != { }) {
        assertion = config.hm.security.sops.enable;
        message = "hm.accounts.email: passwordSopsSecret requires hm.security.sops.enable = true.";
      };

    accounts.email = {
      maildirBasePath = lib.mkDefault cfg.maildirBasePath;

      accounts = lib.mapAttrs (
        name: acct:
        lib.recursiveUpdate acct.extraConfig (
          {
            inherit (acct)
              enable
              primary
              flavor
              address
              realName
              aliases
              ;
          }
          // lib.optionalAttrs (acct.userName != null) { inherit (acct) userName; }
          // lib.optionalAttrs (acct.imap != null) { inherit (acct) imap; }
          // lib.optionalAttrs (acct.smtp != null) { inherit (acct) smtp; }
          // lib.optionalAttrs (acct.jmap != null) { inherit (acct) jmap; }
          // lib.optionalAttrs (acct.gpg != null) { inherit (acct) gpg; }
          // lib.optionalAttrs (acct.signature != { }) { inherit (acct) signature; }
          // lib.optionalAttrs (acct.folders != { }) { inherit (acct) folders; }
          // lib.optionalAttrs (acct.maildir != null) { inherit (acct) maildir; }
          // lib.optionalAttrs (acct.passwordSopsSecret != null) {
            passwordCommand = [
              "cat"
              config.sops.secrets.${acct.passwordSopsSecret}.path
            ];
          }
          // lib.optionalAttrs (acct.passwordSopsSecret == null && acct.passwordCommand != null) {
            inherit (acct) passwordCommand;
          }
        )
      ) cfg.accounts;
    };

    # Auto-register sops secrets for accounts that use passwordSopsSecret
    hm.security.sops.secrets = lib.mapAttrs' (
      _: acct: lib.nameValuePair acct.passwordSopsSecret { }
    ) accountsWithSops;
  };
}
