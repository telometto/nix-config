{
  lib,
  config,
  ...
}:
let
  cfg = config.hm.accounts.contact;

  accountsWithSops = lib.filterAttrs (_: acct: acct.passwordSopsSecret != null) cfg.accounts;

  contactAccountSubmodule = lib.types.submodule {
    options = {
      local = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Local storage configuration (path, type, fileExt, encoding).";
      };

      remote = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [
                  "carddav"
                  "http"
                  "google_contacts"
                ];
                description = "Remote storage type.";
              };

              url = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "The URL of the remote contacts server.";
              };

              userName = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "User name for authentication.";
              };
            };
          }
        );
        default = null;
        description = "Remote storage configuration (carddav, http, google_contacts).";
      };

      passwordSopsSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "accounts/contact/google/password";
        description = ''
          SOPS secret key for this account's password. When set, the module
          auto-registers the secret in hm.security.sops.secrets and wires
          passwordCommand on the remote configuration.
        '';
      };

      passwordCommand = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = ''
          A command that prints the password on stdout. If passwordSopsSecret
          is set, this is auto-populated.
        '';
      };

      extraConfig = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Extra attributes merged into the upstream accounts.contact.accounts entry.";
      };
    };
  };
in
{
  options.hm.accounts.contact = {
    enable = lib.mkEnableOption "Declarative contact account management";

    basePath = lib.mkOption {
      type = lib.types.str;
      default = ".contacts";
      description = "Base directory for contact storage, relative to home.";
    };

    accounts = lib.mkOption {
      type = lib.types.attrsOf contactAccountSubmodule;
      default = { };
      description = "Contact accounts to configure via home-manager's accounts.contact.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.flatten (
        lib.mapAttrsToList (name: acct: [
          {
            assertion = !(acct.passwordSopsSecret != null && acct.passwordCommand != null);
            message = "hm.accounts.contact.accounts.${name}: passwordSopsSecret and passwordCommand are mutually exclusive.";
          }
          {
            assertion =
              acct.remote != null || (acct.passwordSopsSecret == null && acct.passwordCommand == null);
            message = "hm.accounts.contact.accounts.${name}: passwordSopsSecret and passwordCommand require remote to be configured.";
          }
        ]) cfg.accounts
      )
      ++ lib.optional (accountsWithSops != { }) {
        assertion = config.hm.security.sops.enable;
        message = "hm.accounts.contact: passwordSopsSecret requires hm.security.sops.enable = true.";
      };

    accounts.contact = {
      basePath = lib.mkDefault cfg.basePath;

      accounts = lib.mapAttrs (
        name: acct:
        lib.recursiveUpdate acct.extraConfig (
          { }
          // lib.optionalAttrs (acct.local != { }) { inherit (acct) local; }
          // lib.optionalAttrs (acct.remote != null) {
            remote =
              acct.remote
              // lib.optionalAttrs (acct.passwordSopsSecret != null) {
                passwordCommand = [
                  "cat"
                  config.sops.secrets.${acct.passwordSopsSecret}.path
                ];
              }
              // lib.optionalAttrs (acct.passwordSopsSecret == null && acct.passwordCommand != null) {
                inherit (acct) passwordCommand;
              };
          }
        )
      ) cfg.accounts;
    };

    hm.security.sops.secrets = lib.mapAttrs' (
      _: acct: lib.nameValuePair acct.passwordSopsSecret { }
    ) accountsWithSops;
  };
}
