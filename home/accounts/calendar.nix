{
  lib,
  config,
  ...
}:
let
  cfg = config.hm.accounts.calendar;

  accountsWithSops = lib.filterAttrs (_: acct: acct.passwordSopsSecret != null) cfg.accounts;

  calendarAccountSubmodule = lib.types.submodule {
    options = {
      primary = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this is the primary calendar account.";
      };

      primaryCollection = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The primary collection when an account has multiple calendars.";
      };

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
                  "caldav"
                  "http"
                  "google_calendar"
                ];
                description = "Remote storage type.";
              };

              url = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "The URL of the remote calendar server.";
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
        description = "Remote storage configuration (caldav, http, google_calendar).";
      };

      passwordSopsSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "accounts/calendar/google/password";
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
        description = "Extra attributes merged into the upstream accounts.calendar.accounts entry.";
      };
    };
  };
in
{
  options.hm.accounts.calendar = {
    enable = lib.mkEnableOption "Declarative calendar account management";

    basePath = lib.mkOption {
      type = lib.types.str;
      default = ".calendar";
      description = "Base directory for calendar storage, relative to home.";
    };

    accounts = lib.mkOption {
      type = lib.types.attrsOf calendarAccountSubmodule;
      default = { };
      description = "Calendar accounts to configure via home-manager's accounts.calendar.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.mapAttrsToList (name: acct: {
        assertion = !(acct.passwordSopsSecret != null && acct.passwordCommand != null);
        message = "hm.accounts.calendar.accounts.${name}: passwordSopsSecret and passwordCommand are mutually exclusive.";
      }) cfg.accounts
      ++ lib.optional (accountsWithSops != { }) {
        assertion = config.hm.security.sops.enable;
        message = "hm.accounts.calendar: passwordSopsSecret requires hm.security.sops.enable = true.";
      };

    accounts.calendar = {
      basePath = lib.mkDefault cfg.basePath;

      accounts = lib.mapAttrs (
        name: acct:
        {
          inherit (acct) primary;
        }
        // lib.optionalAttrs (acct.primaryCollection != null) {
          inherit (acct) primaryCollection;
        }
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
        // acct.extraConfig
      ) cfg.accounts;
    };

    hm.security.sops.secrets = lib.mapAttrs' (
      _: acct: lib.nameValuePair acct.passwordSopsSecret { }
    ) accountsWithSops;
  };
}
