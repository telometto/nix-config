{ lib, config, ... }:
let
  cfg = config.hm.programs.online-accounts;

  # Email account submodule
  emailAccountModule = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable this email account.";
      };

      address = lib.mkOption {
        type = lib.types.str;
        description = "The email address of this account.";
      };

      realName = lib.mkOption {
        type = lib.types.str;
        description = "Name displayed when sending emails.";
      };

      userName = lib.mkOption {
        type = lib.types.str;
        description = "The server username of this account.";
      };

      passwordCommand = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "A command that prints the account password on standard output.";
      };

      primary = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this is the primary email account.";
      };

      aliases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Alternative email addresses for this account.";
      };

      flavor = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "gmail.com"
            "outlook.office365.com"
            "plain"
          ]
        );
        default = null;
        description = "Email provider flavor for special treatment.";
      };

      imap = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              host = lib.mkOption {
                type = lib.types.str;
                description = "Hostname of IMAP server.";
              };

              port = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                default = null;
                description = "The port on which the IMAP server listens. If null then the default port is used.";
              };

              tls = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to enable TLS/SSL.";
                };

                useStartTls = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether to use STARTTLS.";
                };
              };
            };
          }
        );
        default = null;
        description = "IMAP configuration for this account.";
      };

      smtp = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              host = lib.mkOption {
                type = lib.types.str;
                description = "Hostname of SMTP server.";
              };

              port = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                default = null;
                description = "The port on which the SMTP server listens. If null then the default port is used.";
              };

              tls = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to enable TLS/SSL.";
                };

                useStartTls = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to use STARTTLS.";
                };
              };
            };
          }
        );
        default = null;
        description = "SMTP configuration for this account.";
      };

      folders = lib.mkOption {
        type = lib.types.submodule {
          options = {
            inbox = lib.mkOption {
              type = lib.types.str;
              default = "Inbox";
              description = "Relative path of the inbox mail folder.";
            };

            drafts = lib.mkOption {
              type = lib.types.str;
              default = "Drafts";
              description = "Relative path of the drafts mail folder.";
            };

            sent = lib.mkOption {
              type = lib.types.str;
              default = "Sent";
              description = "Relative path of the sent mail folder.";
            };

            trash = lib.mkOption {
              type = lib.types.str;
              default = "Trash";
              description = "Relative path of the trash mail folder.";
            };
          };
        };
        default = { };
        description = "Standard email folders configuration.";
      };

      thunderbird = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to enable Thunderbird integration for this account.";
        };

        profiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "List of Thunderbird profiles for which this account should be enabled.";
        };
      };
    };
  };

  # Calendar account submodule
  calendarAccountModule = lib.types.submodule {
    options = {
      primary = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this is the primary calendar account.";
      };

      primaryCollection = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The primary collection of the account. Required when an account has multiple collections.";
      };

      local = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              path = lib.mkOption {
                type = lib.types.str;
                description = "The path of the local storage.";
              };

              type = lib.mkOption {
                type = lib.types.enum [
                  "filesystem"
                  "singlefile"
                ];
                default = "filesystem";
                description = "The type of the local storage.";
              };

              fileExt = lib.mkOption {
                type = lib.types.str;
                default = ".ics";
                description = "The file extension to use.";
              };
            };
          }
        );
        default = null;
        description = "Local configuration for the calendar.";
      };

      remote = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [
                  "caldav"
                  "http"
                ];
                description = "The type of the remote storage.";
              };

              url = lib.mkOption {
                type = lib.types.str;
                description = "The URL of the remote storage.";
              };

              userName = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "User name for authentication.";
              };

              passwordCommand = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "A command that prints the password to standard output.";
              };
            };
          }
        );
        default = null;
        description = "Remote configuration for the calendar.";
      };

      khal = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to enable khal access for this calendar.";
        };

        color = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Color in which events in this calendar are displayed. E.g., 'light green' or '#ff0000'.";
        };

        priority = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Priority of a calendar used for coloring.";
        };

        readOnly = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Keep khal from making any changes to this calendar.";
        };

        type = lib.mkOption {
          type = lib.types.enum [
            "calendar"
            "discover"
          ];
          default = "calendar";
          description = "Either a single calendar or a directory with multiple calendars.";
        };
      };

      thunderbird = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to enable Thunderbird integration for this calendar.";
        };

        color = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Display color of the calendar in hex format.";
        };

        readOnly = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Mark calendar as read only.";
        };
      };
    };
  };

  # Contact account submodule
  contactAccountModule = lib.types.submodule {
    options = {
      local = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              path = lib.mkOption {
                type = lib.types.str;
                description = "The path of the local storage.";
              };

              type = lib.mkOption {
                type = lib.types.enum [
                  "filesystem"
                  "singlefile"
                ];
                default = "filesystem";
                description = "The type of the local storage.";
              };

              fileExt = lib.mkOption {
                type = lib.types.str;
                default = ".vcf";
                description = "The file extension to use.";
              };
            };
          }
        );
        default = null;
        description = "Local configuration for the contacts.";
      };

      remote = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.enum [ "carddav" ];
                description = "The type of the remote storage.";
              };

              url = lib.mkOption {
                type = lib.types.str;
                description = "The URL of the remote storage.";
              };

              userName = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "User name for authentication.";
              };

              passwordCommand = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "A command that prints the password to standard output.";
              };
            };
          }
        );
        default = null;
        description = "Remote configuration for the contacts.";
      };

      khard = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to enable khard access for this contact account.";
        };

        type = lib.mkOption {
          type = lib.types.enum [
            "single"
            "discover"
          ];
          default = "single";
          description = "Either a single vdir or multiple automatically discovered vdirs.";
        };
      };

      thunderbird = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to enable Thunderbird integration for this contact account.";
        };
      };
    };
  };
in
{
  options.hm.programs.online-accounts = {
    enable = lib.mkEnableOption "Online accounts configuration (email, calendar, contacts)";

    email = lib.mkOption {
      type = lib.types.attrsOf emailAccountModule;
      default = { };
      description = "Email accounts configuration.";
      example = lib.literalExpression ''
        {
          personal = {
            address = "user@example.com";
            realName = "John Doe";
            userName = "user@example.com";
            passwordCommand = "cat /run/secrets/email-password";
            primary = true;
            imap = {
              host = "imap.example.com";
              port = 993;
              tls.enable = true;
            };
            smtp = {
              host = "smtp.example.com";
              port = 587;
              tls = {
                enable = true;
                useStartTls = true;
              };
            };
          };
        }
      '';
    };

    calendar = lib.mkOption {
      type = lib.types.attrsOf calendarAccountModule;
      default = { };
      description = "Calendar accounts configuration.";
      example = lib.literalExpression ''
        {
          personal = {
            primary = true;
            local.path = "~/.local/share/calendar/personal";
            remote = {
              type = "caldav";
              url = "https://caldav.example.com/personal";
              userName = "user@example.com";
              passwordCommand = "cat /run/secrets/caldav-password";
            };
          };
        }
      '';
    };

    contact = lib.mkOption {
      type = lib.types.attrsOf contactAccountModule;
      default = { };
      description = "Contact accounts configuration.";
      example = lib.literalExpression ''
        {
          personal = {
            local.path = "~/.local/share/contacts/personal";
            remote = {
              type = "carddav";
              url = "https://carddav.example.com/personal";
              userName = "user@example.com";
              passwordCommand = "cat /run/secrets/carddav-password";
            };
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Configure email accounts
    accounts.email.accounts = lib.mkIf (cfg.email != { }) (
      lib.mapAttrs (
        name: emailCfg:
        lib.mkIf emailCfg.enable {
          inherit (emailCfg)
            address
            realName
            userName
            primary
            aliases
            flavor
            folders
            ;

          passwordCommand = lib.mkIf (emailCfg.passwordCommand != null) emailCfg.passwordCommand;

          imap = lib.mkIf (emailCfg.imap != null) {
            inherit (emailCfg.imap) host;
            port = lib.mkIf (emailCfg.imap.port != null) emailCfg.imap.port;
            tls = {
              inherit (emailCfg.imap.tls) enable useStartTls;
            };
          };

          smtp = lib.mkIf (emailCfg.smtp != null) {
            inherit (emailCfg.smtp) host;
            port = lib.mkIf (emailCfg.smtp.port != null) emailCfg.smtp.port;
            tls = {
              inherit (emailCfg.smtp.tls) enable useStartTls;
            };
          };

          thunderbird = lib.mkIf emailCfg.thunderbird.enable {
            enable = true;
            profiles = lib.mkIf (emailCfg.thunderbird.profiles != [ ]) emailCfg.thunderbird.profiles;
          };
        }
      ) cfg.email
    );

    # Configure calendar accounts
    accounts.calendar.accounts = lib.mkIf (cfg.calendar != { }) (
      lib.mapAttrs (name: calCfg: {
        inherit name;
        inherit (calCfg) primary;

        primaryCollection = lib.mkIf (calCfg.primaryCollection != null) calCfg.primaryCollection;

        local = lib.mkIf (calCfg.local != null) {
          inherit (calCfg.local) path type fileExt;
        };

        remote = lib.mkIf (calCfg.remote != null) ({
          inherit (calCfg.remote) type url;
          userName = lib.mkIf (calCfg.remote.userName != null) calCfg.remote.userName;
          passwordCommand = lib.mkIf (calCfg.remote.passwordCommand != null) calCfg.remote.passwordCommand;
        });

        khal = lib.mkIf calCfg.khal.enable {
          enable = true;
          inherit (calCfg.khal) priority readOnly type;
          color = lib.mkIf (calCfg.khal.color != null) calCfg.khal.color;
        };

        thunderbird = lib.mkIf calCfg.thunderbird.enable {
          enable = true;
          inherit (calCfg.thunderbird) readOnly;
          color = lib.mkIf (calCfg.thunderbird.color != null) calCfg.thunderbird.color;
        };
      }) cfg.calendar
    );

    # Configure contact accounts
    accounts.contact.accounts = lib.mkIf (cfg.contact != { }) (
      lib.mapAttrs (name: contactCfg: {
        inherit name;

        local = lib.mkIf (contactCfg.local != null) {
          inherit (contactCfg.local) path type fileExt;
        };

        remote = lib.mkIf (contactCfg.remote != null) {
          inherit (contactCfg.remote) type url;
          userName = lib.mkIf (contactCfg.remote.userName != null) contactCfg.remote.userName;
          passwordCommand = lib.mkIf (
            contactCfg.remote.passwordCommand != null
          ) contactCfg.remote.passwordCommand;
        };

        khard = lib.mkIf contactCfg.khard.enable {
          enable = true;
          inherit (contactCfg.khard) type;
        };

        thunderbird = lib.mkIf contactCfg.thunderbird.enable {
          enable = true;
        };
      }) cfg.contact
    );
  };
}
